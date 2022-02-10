using ThreadSafeDicts # private repo
using ProgressMeter
using Dates
using FinanceDB
using Statistics

@show Threads.nthreads()
include("./02-loadmmap.jl")

# Config
	FinanceDB.SetDataFolder("/mnt/data/mmap")
	pairName = "BTC_USDT"
	seconds = (
		Day = 3600 * 24,
		Month = 3600 * 24 * 30,
		)
	intervals = (
			m15 = Minute(15),
			m20 = Minute(20),
			m30 = Minute(30),
			H1  = Hour(1), # main
			H2  = Hour(2),
			H3  = Hour(3),
			H4  = Hour(4),
			H6  = Hour(6),
			H8  = Hour(8),
			H12 = Hour(12),
			D1  = Day(1),
			D3  = Day(3),
			D5  = Day(5),
			W1  = Week(1),
			M1  = Month(1),
			M3  = Month(3),
			M6  = Month(6),
		)

# Method: Smooth Timestamp
	function Smooth!(tsList::Vector{Int32})::Vector{Int32}
		lastTs      = copy(tsList[1])   # last continuous ts
		startPos    = 2                 # [1,1,2,2,2] ==> 1,3
		i           = max(3,findfirst(x->x!==lastTs,tsList))
		prevI       = startPos
		prog        = ProgressMeter.Progress(length(tsList)-i)
		while !isnothing(i)
			next!(prog; step=i-prevI)
			if tsList[i] > lastTs     # trigger smooth
				if i > startPos+1
					cacheDiff = lastTs - tsList[startPos-1]
					numModi   = i - startPos
					valStep   = cacheDiff / numModi
					for j in startPos:(i-2)
						tsList[j] = round(Int32,
							tsList[startPos-1] + (j-startPos+1)*valStep
							)
					end
				end
				startPos  = i              # Mark start position
				lastTs    = tsList[i]
			elseif tsList[i] < lastTs    # unexpected data
				if tsList[startPos-1] < lastTs
					tsList[startPos-1] = tsList[i]
				end
				tsList[i] = lastTs
			end
			prevI  = i
			i      = findnext(x->x!==tsList[i], tsList, i)
		end
		cacheDiff = lastTs - tsList[startPos-1]
		numModi   = length(tsList) - startPos + 1
		valStep   = cacheDiff / numModi
		for j in startPos:length(tsList)
			tsList[j] = round(Int32,
				tsList[startPos-1] + (j-startPos+1)*valStep
				)
		end
		return tsList
		end

# Timezone + 8
	function dt2unix(dt::DateTime)::Int32
		return round(Int32, datetime2unix(dt - Hour(8)))
		end
	function unix2dt(ts::Int32)::DateTime
		return unix2datetime(ts) + Hour(8)
		end
	function SelectPeriod(fromDate::DateTime, toDate::DateTime, targetVector::Vector)::UnitRange{Int64}
		fromTs, toTs = dt2unix(fromDate), dt2unix(toDate)
		fromN = findfirst(x->x>=fromTs, targetVector)
		toN   = findlast(x->x<= toTs, targetVector)
		return fromN:toN
		end

#= DF structure
	TxRowsDF == DataFrame(
		:AddressId => rand(UInt32),
		:Amount => rand(Float64),
		:Timestamp => rand(Int32),
		)
	TxStateDF == DataFrame(
		:InputCount => rand(UInt16),
		:OutputCount => rand(UInt16),
		:Fee => rand(Float32),
		:Value => rand(Float32),
		:Timestamp => rand(Int32),
		)
	=#

# Runtime Vars
	mutable struct TransactionRow
		addrId::UInt32
		tagNew::Bool
		amount::Float32
		ts::Int32
		end

# Runtime Address
	mutable struct AddressStatistics
		# timestamp
		TimestampCreated::Int32
		TimestampLastActive::Int32
		TimestampLastReceived::Int32
		TimestampLastPayed::Int32
		# amount
		AmountIncomeTotal::Float64
		AmountExpenseTotal::Float64
		# statistics
		NumTxInTotal::Int32
		NumTxOutTotal::Int32
		# relevant usdt amount
		UsdtPayed4Input::Float64
		UsdtReceived4Output::Float64
		AveragePurchasePrice::Float32
		LastSellPrice::Float32
		# calculated extra
		UsdtNetRealized::Float64
		UsdtNetUnrealized::Float64
		Balance::Float64 # btc
		end
	AddressState  = ThreadSafeDict{UInt32,AddressStatistics}()
	function touch!(tr::TransactionRow)::Nothing
		coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, tr.ts)
		coinUsdt  = abs(coinPrice * tr.amount)
		if tr.tagNew
			if tr.amount >= 0
				AddressState[tr.addrId] = AddressStatistics(
						# timestamp
						tr.ts, # TimestampCreated
						tr.ts, # TimestampLastActive
						tr.ts, # TimestampLastReceived
						tr.ts, # TimestampLastPayed
						# amount
						tr.amount, # AmountIncomeTotal
						0, # AmountExpenseTotal
						# statistics
						1, # NumTxInTotal
						0, # NumTxOutTotal
						# relevant usdt amount
						coinUsdt, # UsdtPayed4Input
						0, # UsdtReceived4Output
						coinPrice, # AveragePurchasePrice
						coinPrice, # LastSellPrice
						# calculated extra
						0, # UsdtNetRealized
						0, # UsdtNetUnrealized
						tr.amount, # Balance
					)
			else
				# @warn "unexpected address when $(tr.ts)"
				AddressState[tr.addrId] = AddressStatistics(
					# timestamp
					tr.ts, # TimestampCreated
					tr.ts, # TimestampLastActive
					tr.ts, # TimestampLastReceived
					tr.ts, # TimestampLastPayed
					# amount
					0, # AmountIncomeTotal
					abs(tr.amount), # AmountExpenseTotal
					# statistics
					0, # NumTxInTotal
					1, # NumTxOutTotal
					# relevant usdt amount
					0, # UsdtPayed4Input
					coinUsdt, # UsdtReceived4Output
					coinPrice, # AveragePurchasePrice
					coinPrice, # LastSellPrice
					# calculated extra
					coinUsdt, # UsdtNetRealized
					0, # UsdtNetUnrealized
					tr.amount, # Balance
				)
			end
			return nothing
		end
		refStat = Ref(AddressState[tr.addrId])
		if tr.amount < 0
			refStat[].AmountExpenseTotal -= tr.amount
			refStat[].NumTxOutTotal      += 1
			refStat[].TimestampLastPayed = max(refStat[].TimestampLastPayed, tr.ts)
			refStat[].UsdtReceived4Output += coinUsdt
			refStat[].LastSellPrice      = coinPrice
		else
			refStat[].AmountIncomeTotal  += tr.amount
			refStat[].NumTxInTotal       += 1
			refStat[].TimestampLastReceived = max(refStat[].TimestampLastReceived, tr.ts)
			refStat[].UsdtPayed4Input += coinUsdt
			refStat[].AveragePurchasePrice = Float32(
				(refStat[].AveragePurchasePrice * refStat[].Balance + coinUsdt) / (refStat[].Balance + tr.amount)
				)
		end
		if refStat[].Balance < 0
			refStat[].TimestampCreated = min(refStat[].TimestampCreated, tr.ts)
		end
		refStat[].TimestampLastActive = max(refStat[].TimestampLastActive, tr.ts)
		refStat[].Balance += tr.amount
		refStat[].UsdtNetRealized = refStat[].UsdtReceived4Output - refStat[].UsdtPayed4Input
		refStat[].UsdtNetUnrealized = (coinPrice-refStat[].AveragePurchasePrice) * refStat[].Balance
		nothing
		end

# Address Snapshot
	mutable struct AddressSnapshot
		# for statistics
		BalanceVector::Vector{Float64}
		TsActiveVector::Vector{Int32}
		# in profit
		NumInProfitRealized::Int64
		NumInProfitUnrealized::Int64
		AmountInProfitRealized::Float64
		AmountInProfitUnrealized::Float64
		# in loss
		NumInLossRealized::Int64
		NumInLossUnrealized::Int64
		AmountInLossRealized::Float64
		AmountInLossUnrealized::Float64
		end
	tplAddressSnapshot = AddressSnapshot(Float64[], Int32[], zeros(length(AddressSnapshot.types)-2)...)
	function TakeSnapshot()::AddressSnapshot
		ret = deepcopy(tplAddressSnapshot)
		for p in AddressState
			push!(ret.BalanceVector, p[2].Balance)
			push!(ret.TsActiveVector, p[2].TimestampLastActive)
			if p[2].UsdtNetRealized > 0
				ret.NumInProfitRealized += 1
				ret.AmountInProfitRealized += p[2].UsdtNetRealized
			elseif p[2].UsdtNetRealized < 0
				ret.NumInLossRealized += 1
				ret.AmountInLossRealized -= p[2].UsdtNetRealized
			end
			if p[2].UsdtNetUnrealized > 0
				ret.NumInProfitUnrealized += 1
				ret.AmountInProfitUnrealized += p[2].UsdtNetUnrealized
			elseif p[2].UsdtNetUnrealized < 0
				ret.NumInLossUnrealized += 1
				ret.AmountInLossUnrealized -= p[2].UsdtNetUnrealized
			end
		end
		return ret
		end

# New Procedure Purpose: CalcUint
	mutable struct CalcCell
		resultType::DataType
		handler::Function
		end
	Calculations = CalcCell[]
	mutable struct CellAddressComparative
		numTotalActive::Int32
		amountTotalTransfer::Float32
		percentNumNew::Float32
		percentNumSending::Float32
		percentNumReceiving::Float32
		end
	mutable struct CellAddressDirection
		numChargePercentBelow25::Int32
		numChargePercentBelow50::Int32
		numChargePercentBelow80::Int32
		numChargePercentEquals100::Int32
		numWithdrawPercentBelow50::Int32
		numWithdrawPercentAbove75::Int32
		numWithdrawPercentAbove90::Int32
		amountChargePercentBelow25::Float32
		amountChargePercentBelow50::Float32
		amountChargePercentBelow80::Float32
		amountChargePercentEquals100::Float32
		amountWithdrawPercentBelow50::Float32
		amountWithdrawPercentAbove75::Float32
		amountWithdrawPercentAbove90::Float32
		end
	mutable struct CellAddressAccumulation
		numWakeupW1Sending::Float32
		numWakeupM1Sending::Float32
		numContinuousD1Buying::Float32
		numContinuousD3Buying::Float32
		numContinuousW1Buying::Float32
		amountWakeupW1Sending::Float32
		amountWakeupM1Sending::Float32
		amountContinuousD1Buying::Float32
		amountContinuousD3Buying::Float32
		amountContinuousW1Buying::Float32
		end
	mutable struct CellAddressSupplier
		balanceSupplierMean::Float32
		balanceSupplierStd::Float32
		balanceSupplierPercent20::Float32
		balanceSupplierPercent40::Float32
		balanceSupplierMiddle::Float32
		balanceSupplierPercent60::Float32
		balanceSupplierPercent80::Float32
		amountSupplierBalanceBelow20::Float32
		amountSupplierBalanceAbove80::Float32
		end
	mutable struct CellAddressUsdtDiff
		numRealizedProfit::Int32
		numRealizedLoss::Int32
		amountRealizedProfit::Float32
		amountRealizedLoss::Float32
		end
	function CalcAddressComparative(txs::Vector{TransactionRow})::CellAddressComparative
		ret = CellAddressComparative(
				length(txs),
				reduce(+, map(x->abs(x.amount),txs))/2,
				count(x->x.tagNew, txs),
				count(x->x.amount<=0, txs),
				count(x->x.amount>0, txs),
			)
		return ret
		end
	function CalcAddressDirection(txs::Vector{TransactionRow})::CellAddressDirection
		concreteIndexes  = map(x->!x.tagNew,txs)
		concreteBalances = map(x->abs(AddressState[x.addrId].Balance), txs[concreteIndexes])
		concretePercents = map(x->x.amount, txs[concreteIndexes]) ./ concreteBalances
		concreteAmounts  = map(x->abs(x.amount), txs[concreteIndexes])
		tmpIndexes = (
			cpb25 = map(x-> 0.0 < x <= 0.25, concretePercents),
			cpb50 = map(x-> 0.25 < x <= 0.5, concretePercents),
			cpb80 = map(x-> 0.50 < x <= 0.8, concretePercents),
			wpb50 = map(x-> -0.5 < x < 0.0, concretePercents),
			wpa75 = map(x-> -0.9 < x <= -0.75, concretePercents),
			wpa90 = map(x-> -1.1 < x <= -0.90, concretePercents),
			)
		newIndexes = map(x->x.tagNew, txs)
		ret = CellAddressDirection(
				sum(tmpIndexes.cpb25),
				sum(tmpIndexes.cpb50),
				sum(tmpIndexes.cpb80),
				sum(newIndexes),
				sum(tmpIndexes.wpb50),
				sum(tmpIndexes.wpa75),
				sum(tmpIndexes.wpa90),
				
				reduce(+, concreteAmounts[tmpIndexes.cpb25]),
				reduce(+, concreteAmounts[tmpIndexes.cpb50]),
				reduce(+, concreteAmounts[tmpIndexes.cpb80]),
				reduce(+, map(x->abs(x.amount), txs[newIndexes])),
				reduce(+, concreteAmounts[tmpIndexes.wpb50]),
				reduce(+, concreteAmounts[tmpIndexes.wpa75]),
				reduce(+, concreteAmounts[tmpIndexes.wpa90]),
			)
		return ret
		end
	function CalcAddressAccumulation(txs::Vector{TransactionRow})::CellAddressAccumulation
		tsMin = min(txs[1].ts, txs[end].ts)
		tsMax = max(txs[1].ts, txs[end].ts)
		concreteIndexes  = map(x->!x.tagNew,txs)
		concreteLastPayed    = map(x->AddressState[x.addrId].TimestampLastPayed, txs[concreteIndexes])
		concreteLastReceived = map(x->AddressState[x.addrId].TimestampLastReceived, txs[concreteIndexes])
		concreteAmounts      = map(x->abs(x.amount), txs[concreteIndexes])
		tmpIndexes = (
				wakeupW1 = map(x->tsMax-x > 7seconds.Day, concreteLastPayed),
				wakeupM1 = map(x->tsMax-x > seconds.Month, concreteLastPayed),
				contiD1  = map(x->x-tsMin > seconds.Day, concreteLastReceived),
				contiD3  = map(x->x-tsMin > 3seconds.Day, concreteLastReceived),
				contiW1  = map(x->x-tsMin > 7seconds.Day, concreteLastReceived),
			)
		ret = CellAddressAccumulation(
				sum(tmpIndexes.wakeupW1),
				sum(tmpIndexes.wakeupM1),
				sum(tmpIndexes.contiD1),
				sum(tmpIndexes.contiD3),
				sum(tmpIndexes.contiW1),
				
				reduce(+, concreteAmounts[tmpIndexes.wakeupW1]),
				reduce(+, concreteAmounts[tmpIndexes.wakeupM1]),
				reduce(+, concreteAmounts[tmpIndexes.contiD1]),
				reduce(+, concreteAmounts[tmpIndexes.contiD3]),
				reduce(+, concreteAmounts[tmpIndexes.contiW1]),
			)
		return ret
		end
	function CalcAddressSupplier(txs::Vector{TransactionRow})::CellAddressSupplier
		concreteIndexes  = map(x->!x.tagNew && x.amount<0, txs)
		concreteBalances = map(x->abs(AddressState[x.addrId].Balance), txs[concreteIndexes])
		concreteAmounts  = map(x->abs(x.amount), txs[concreteIndexes])
		sortedBalances = sort(concreteBalances)
		ret = CellAddressSupplier(
				sum(sortedBalances) / length(sortedBalances),
				Statistics.std(sortedBalances),
				sortedBalances[floor(Int, 0.2*end)],
				sortedBalances[floor(Int, 0.4*end)],
				sortedBalances[round(Int, 0.5*end)],
				sortedBalances[ceil(Int, 0.6*end)],
				sortedBalances[ceil(Int, 0.8*end)],
				reduce(+, concreteAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.2*end)], concreteBalances)
					]),
				reduce(+, concreteAmounts[
					map(x -> x >= sortedBalances[ceil(Int, 0.8*end)], concreteBalances)
					]),
			)
		return ret
		end
	function CalcAddressUsdtDiff(txs::Vector{TransactionRow})::CellAddressUsdtDiff
		ret = CellAddressUsdtDiff(zeros(length(CellAddressUsdtDiff.types))...)
		concreteIndexes  = map(x->!x.tagNew && x.amount<0, txs)
		for r in txs[concreteIndexes]
			coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, r.ts)
			boughtPrice = AddressState[r.addrId].AveragePurchasePrice
			if coinPrice > boughtPrice
				ret.numRealizedProfit += 1
				ret.amountRealizedProfit += (coinPrice-boughtPrice) * abs(r.amount)
			else
				ret.numRealizedLoss += 1
				ret.amountRealizedLoss += (boughtPrice-coinPrice) * abs(r.amount)
			end
		end
		return ret
		end
	push!(Calculations, CalcCell(
		CellAddressComparative, CalcAddressComparative))
	push!(Calculations, CalcCell(
		CellAddressDirection, CalcAddressDirection))
	push!(Calculations, CalcCell(
		CellAddressAccumulation, CalcAddressAccumulation))
	push!(Calculations, CalcCell(
		CellAddressSupplier, CalcAddressSupplier))
	push!(Calculations, CalcCell(
		CellAddressUsdtDiff, CalcAddressUsdtDiff))
	struct ResultCalculations
		# CellAddressComparative
		numTotalActive::Int32
		amountTotalTransfer::Float32
		percentNumNew::Float32
		percentNumSending::Float32
		percentNumReceiving::Float32
		# CellAddressDirection
		numChargePercentBelow25::Int32
		numChargePercentBelow50::Int32
		numChargePercentBelow80::Int32
		numChargePercentEquals100::Int32
		numWithdrawPercentBelow50::Int32
		numWithdrawPercentAbove75::Int32
		numWithdrawPercentAbove90::Int32
		amountChargePercentBelow25::Float32
		amountChargePercentBelow50::Float32
		amountChargePercentBelow80::Float32
		amountChargePercentEquals100::Float32
		amountWithdrawPercentBelow50::Float32
		amountWithdrawPercentAbove75::Float32
		amountWithdrawPercentAbove90::Float32
		# CellAddressAccumulation
		numWakeupW1Sending::Float32
		numWakeupM1Sending::Float32
		numContinuousD1Buying::Float32
		numContinuousD3Buying::Float32
		numContinuousW1Buying::Float32
		amountWakeupW1Sending::Float32
		amountWakeupM1Sending::Float32
		amountContinuousD1Buying::Float32
		amountContinuousD3Buying::Float32
		amountContinuousW1Buying::Float32
		# CellAddressSupplier
		balanceSupplierMean::Float32
		balanceSupplierStd::Float32
		balanceSupplierPercent20::Float32
		balanceSupplierPercent40::Float32
		balanceSupplierMiddle::Float32
		balanceSupplierPercent60::Float32
		balanceSupplierPercent80::Float32
		amountSupplierBalanceBelow20::Float32
		amountSupplierBalanceAbove80::Float32
		# CellAddressUsdtDiff
		numRealizedProfit::Int32
		numRealizedLoss::Int32
		amountRealizedProfit::Float32
		amountRealizedLoss::Float32
		end
	function DoCalculations(txs::Vector{TransactionRow})::ResultCalculations
		listTask = Vector{Task}(undef,length(Calculations))
		for i in 1:length(Calculations)
			listTask[i] = Threads.@spawn Calculations[i].handler(txs)
		end
		wait.(listTask)
		return ResultCalculations(
			# CellAddressComparative
			listTask[1].result.numTotalActive,
			listTask[1].result.amountTotalTransfer,
			listTask[1].result.percentNumNew,
			listTask[1].result.percentNumSending,
			listTask[1].result.percentNumReceiving,
			# CellAddressDirection
			listTask[2].result.numChargePercentBelow25,
			listTask[2].result.numChargePercentBelow50,
			listTask[2].result.numChargePercentBelow80,
			listTask[2].result.numChargePercentEquals100,
			listTask[2].result.numWithdrawPercentBelow50,
			listTask[2].result.numWithdrawPercentAbove75,
			listTask[2].result.numWithdrawPercentAbove90,
			listTask[2].result.amountChargePercentBelow25,
			listTask[2].result.amountChargePercentBelow50,
			listTask[2].result.amountChargePercentBelow80,
			listTask[2].result.amountChargePercentEquals100,
			listTask[2].result.amountWithdrawPercentBelow50,
			listTask[2].result.amountWithdrawPercentAbove75,
			listTask[2].result.amountWithdrawPercentAbove90,
			# CellAddressAccumulation
			listTask[3].result.numWakeupW1Sending,
			listTask[3].result.numWakeupM1Sending,
			listTask[3].result.numContinuousD1Buying,
			listTask[3].result.numContinuousD3Buying,
			listTask[3].result.numContinuousW1Buying,
			listTask[3].result.amountWakeupW1Sending,
			listTask[3].result.amountWakeupM1Sending,
			listTask[3].result.amountContinuousD1Buying,
			listTask[3].result.amountContinuousD3Buying,
			listTask[3].result.amountContinuousW1Buying,
			# CellAddressSupplier
			listTask[4].result.balanceSupplierMean,
			listTask[4].result.balanceSupplierStd,
			listTask[4].result.balanceSupplierPercent20,
			listTask[4].result.balanceSupplierPercent40,
			listTask[4].result.balanceSupplierMiddle,
			listTask[4].result.balanceSupplierPercent60,
			listTask[4].result.balanceSupplierPercent80,
			listTask[4].result.amountSupplierBalanceBelow20,
			listTask[4].result.amountSupplierBalanceAbove80,
			# CellAddressUsdtDiff
			listTask[5].result.numRealizedProfit,
			listTask[5].result.numRealizedLoss,
			listTask[5].result.amountRealizedProfit,
			listTask[5].result.amountRealizedLoss,
		)
		end


# Processing
	fromDate = DateTime(2018,1, 1, 0, 0, 0)
	toDate   = DateTime(2021,12,31,23,59,59)
	posStart = SelectPeriod(fromDate, toDate, TxRowsDF.Timestamp)[1]
	# Sum data before, you can save this to a jld2 file
	# we suggest use the start time of market data, 2017
	prog = ProgressMeter.Progress(posStart-2)
	AddressState.enabled = false
	for i in 1:posStart-1
		addrId, amount, ts = TxRowsDF[i,:]
		touch!(TransactionRow(
			addrId, !haskey(AddressState, addrId), amount, ts
			))
		next!(prog)
	end
	AddressState.enabled = true
	# now it's time to process real stuff

	prevPosEnd   = posStart - 10
	thisPosEnd   = posStart - 10
	thisPosStart = posStart - 10
	for dt in fromDate:Hour(3):toDate
		tsStart = dt2unix(dt)
		thisPosStart = findnext(x->x>=tsStart,
			TxRowsDF.Timestamp, prevPosEnd)
		thisPosEnd   = findnext(x->x>=dt2unix(dt+Hour(3)),
			TxRowsDF.Timestamp, prevPosEnd)
		if isnothing(thisPosEnd)
			break
		end
		v = [ TransactionRow(
			TxRowsDF[i,:AddressId],
			!haskey(AddressState, TxRowsDF[i,:AddressId]),
			TxRowsDF[i,:Amount],
			TxRowsDF[i,:Timestamp],
			) for i in thisPosStart:thisPosEnd ]
		res = DoCalculations(Calculations)
	end
		




# Analyze results
	# you are free to process simple indicators first
	# judge tx direction
	# compare with previous savepoint's account info
	# classify them into groups
	# trigger corresponding recorders
	# we do have snapshot formats of data, try split them into chunks! it'll do good to both you and your deep neural network!
	# ...








































