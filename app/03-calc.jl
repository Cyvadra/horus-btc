using ProgressMeter
using Dates
using Statistics
# private repos
using FinanceDB
using ThreadSafeDicts
using AddressService

@show Threads.nthreads()
include("./02-loadmmap.jl")

# Config
	FinanceDB.SetDataFolder("/mnt/data/mmap")
	pairName = "BTC_USDT"
	seconds = (
		Hour  = 3600,
		Day   = 3600 * 24,
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

	function touch!(tr::TransactionRow)::Nothing
		coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, tr.ts)
		coinUsdt  = abs(coinPrice * tr.amount)
		pos       = tr.addrId
		if tr.tagNew
			if tr.amount >= 0
				AddressService.SetField(:TimestampCreated, pos, tr.ts)
				AddressService.SetField(:TimestampLastActive, pos, tr.ts)
				AddressService.SetField(:TimestampLastReceived, pos, tr.ts)
				AddressService.SetField(:TimestampLastPayed, pos, tr.ts)
				AddressService.SetField(:AmountIncomeTotal, pos, tr.amount)
				AddressService.SetField(:AmountExpenseTotal, pos, 0.0)
				AddressService.SetField(:NumTxInTotal, pos, 1)
				AddressService.SetField(:NumTxOutTotal, pos, 0)
				AddressService.SetField(:UsdtPayed4Input, pos, coinUsdt)
				AddressService.SetField(:UsdtReceived4Output, pos, 0.0)
				AddressService.SetField(:AveragePurchasePrice, pos, coinPrice)
				AddressService.SetField(:LastSellPrice, pos, coinPrice)
				AddressService.SetField(:UsdtNetRealized, pos, 0.0)
				AddressService.SetField(:UsdtNetUnrealized, pos, 0.0)
				AddressService.SetField(:Balance, pos, tr.amount)
			else
				AddressService.SetField(:TimestampCreated, pos, tr.ts)
				AddressService.SetField(:TimestampLastActive, pos, tr.ts)
				AddressService.SetField(:TimestampLastReceived, pos, tr.ts)
				AddressService.SetField(:TimestampLastPayed, pos, tr.ts)
				AddressService.SetField(:AmountIncomeTotal, pos, 0.0)
				AddressService.SetField(:AmountExpenseTotal, pos, abs(tr.amount))
				AddressService.SetField(:NumTxInTotal, pos, 0)
				AddressService.SetField(:NumTxOutTotal, pos, 1)
				AddressService.SetField(:UsdtPayed4Input, pos, 0.0)
				AddressService.SetField(:UsdtReceived4Output, pos, coinUsdt)
				AddressService.SetField(:AveragePurchasePrice, pos, coinPrice)
				AddressService.SetField(:LastSellPrice, pos, coinPrice)
				AddressService.SetField(:UsdtNetRealized, pos, coinUsdt)
				AddressService.SetField(:UsdtNetUnrealized, pos, 0.0)
				AddressService.SetField(:Balance, pos, tr.amount)
			end
			return nothing
		end
		addrRO = AddressService.GetRow(pos)
		if tr.amount < 0
			AddressService.SetFieldDiff(:AmountExpenseTotal, pos, -tr.amount)
			AddressService.SetFieldDiff(:NumTxOutTotal, pos, 1)
			if addrRO.TimestampLastPayed < tr.ts
				AddressService.SetField(:TimestampLastPayed, pos, tr.ts)
			end
			AddressService.SetFieldDiff(:UsdtReceived4Output, pos, coinUsdt)
			AddressService.SetField(:LastSellPrice, pos, coinPrice)
		else
			AddressService.SetFieldDiff(:AmountIncomeTotal, pos, tr.amount)
			AddressService.SetFieldDiff(:NumTxInTotal, pos, 1)
			if addrRO.TimestampLastReceived < tr.ts
				AddressService.SetField(:TimestampLastReceived, pos, tr.ts)
			end
			AddressService.SetFieldDiff(:UsdtPayed4Input, pos, coinUsdt)
			if addrRO.Balance + tr.amount > 1e-9
				AddressService.SetField(:AveragePurchasePrice, pos,
					(coinUsdt + addrRO.AveragePurchasePrice * addrRO.Balance) / (addrRO.Balance + tr.amount) )
			end
		end
		if addrRO.Balance < 0 && addrRO.TimestampCreated > tr.ts
			AddressService.SetField(:TimestampCreated, pos, tr.ts)
		end
		if addrRO.TimestampLastActive < tr.ts
			AddressService.SetField(:TimestampLastActive, pos, tr.ts)
		end
		AddressService.SetFieldDiff(:Balance, pos, tr.amount)
		AddressService.SetField(:UsdtNetRealized, pos,
			 AddressService.GetField(:UsdtReceived4Output,pos) - AddressService.GetField(:UsdtPayed4Input,pos)
			 )
		AddressService.SetField(:UsdtNetUnrealized, pos,
			 (coinPrice-AddressService.GetField(:AveragePurchasePrice,pos)) * AddressService.GetField(:Balance,pos)
			 )
		nothing
		end

# New Procedure Purpose: CalcUint
	mutable struct CalcCell
		resultType::DataType
		handler::Function
		end
	Calculations = CalcCell[]
	mutable struct CellAddressComparative
		numTotalActive::Int32
		numTotalRows::Int32
		amountTotalTransfer::Float32
		percentBiasReference::Float32
		percentNumNew::Float32
		percentNumSending::Float32
		percentNumReceiving::Float32
		end
	mutable struct CellAddressDirection
		numChargePercentBelow10::Int32
		numChargePercentBelow25::Int32
		numChargePercentBelow50::Int32
		numChargePercentBelow80::Int32
		numChargePercentBelow95::Int32
		numChargePercentEquals100::Int32
		numWithdrawPercentBelow10::Int32
		numWithdrawPercentBelow25::Int32
		numWithdrawPercentBelow50::Int32
		numWithdrawPercentAbove80::Int32
		numWithdrawPercentAbove95::Int32
		amountChargePercentBelow10::Float32
		amountChargePercentBelow25::Float32
		amountChargePercentBelow50::Float32
		amountChargePercentBelow80::Float32
		amountChargePercentBelow95::Float32
		amountChargePercentEquals100::Float32
		amountWithdrawPercentBelow10::Float32
		amountWithdrawPercentBelow25::Float32
		amountWithdrawPercentBelow50::Float32
		amountWithdrawPercentAbove80::Float32
		amountWithdrawPercentAbove95::Float32
		end
	mutable struct CellAddressAccumulation
		numRecentD3Sending::Int32
		numWakeupW1Sending::Int32
		numWakeupM1Sending::Int32
		numRecentD3Buying::Int32
		numWakeupW1Buying::Int32
		numWakeupM1Buying::Int32
		numContinuousD1Sending::Int32
		numContinuousD3Sending::Int32
		numContinuousW1Sending::Int32
		numContinuousD1Buying::Int32
		numContinuousD3Buying::Int32
		numContinuousW1Buying::Int32
		amountRecentD3Sending::Float32
		amountWakeupW1Sending::Float32
		amountWakeupM1Sending::Float32
		amountRecentD3Buying::Float32
		amountWakeupW1Buying::Float32
		amountWakeupM1Buying::Float32
		amountContinuousD1Sending::Float32
		amountContinuousD3Sending::Float32
		amountContinuousW1Sending::Float32
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
		balanceSupplierPercent95::Float32
		amountSupplierBalanceBelow20::Float32
		amountSupplierBalanceBelow40::Float32
		amountSupplierBalanceBelow60::Float32
		amountSupplierBalanceBelow80::Float32
		amountSupplierBalanceAbove95::Float32
		end
	mutable struct CellAddressUsdtDiff
		numRealizedProfit::Int32
		numRealizedLoss::Int32
		amountRealizedProfitBillion::Float64
		amountRealizedLossBillion::Float64
		end
	function CalcAddressComparative(txs::Vector{TransactionRow})::CellAddressComparative
		lenUnique  = length( unique(map(x->x.addrId, txs)) )
		biasAmount = reduce(+, map(x->x.amount,txs))
		estAmount  = (reduce(+, map(x->abs(x.amount),txs)) - biasAmount) / 2
		ret = CellAddressComparative(
				lenUnique,
				length(txs),
				estAmount,
				biasAmount / estAmount,
				length(unique(
					map(x->x.addrId,
						txs[map(x->x.tagNew, txs)])
					)) / length(txs),
				count(x->x.amount<=0, txs) / length(txs),
				count(x->x.amount>0, txs) / length(txs),
			)
		return ret
		end
	function CalcAddressDirection(txs::Vector{TransactionRow})::CellAddressDirection
		concreteIndexes  = map(x->!x.tagNew,txs)
		concreteBalances = map(id->AddressService.GetField(:Balance,id),
			map(x->x.addrId, txs[concreteIndexes])
			)
		concretePercents = map(x->x.amount, txs[concreteIndexes]) ./ concreteBalances
		concreteAmounts  = abs.(map(x->x.amount, txs[concreteIndexes]))
		tmpIndexes = (
			cpb10 = map(x-> 0.00 < x <= 0.10, concretePercents),
			cpb25 = map(x-> 0.10 < x <= 0.25, concretePercents),
			cpb50 = map(x-> 0.25 < x <= 0.50, concretePercents),
			cpb80 = map(x-> 0.50 < x <= 0.80, concretePercents),
			cpb95 = map(x-> 0.80 < x <= 0.95, concretePercents),
			cpe100= map(x->x.tagNew, txs),
			wpb10 = map(x-> -0.10 <= x < 0.0, concretePercents),
			wpb25 = map(x-> -0.25 <= x < 0.10, concretePercents),
			wpb50 = map(x-> -0.50 <= x < 0.25, concretePercents),
			wpa80 = map(x-> -0.95 < x <= -0.80, concretePercents),
			wpa95 = map(x-> -1.1 < x <= -0.95, concretePercents),
			)
		ret = CellAddressDirection(
				sum(tmpIndexes.cpb10),
				sum(tmpIndexes.cpb25),
				sum(tmpIndexes.cpb50),
				sum(tmpIndexes.cpb80),
				sum(tmpIndexes.cpb95),
				sum(tmpIndexes.cpe100),
				sum(tmpIndexes.wpb10),
				sum(tmpIndexes.wpb25),
				sum(tmpIndexes.wpb50),
				sum(tmpIndexes.wpa80),
				sum(tmpIndexes.wpa95),

				reduce(+, concreteAmounts[tmpIndexes.cpb10]),
				reduce(+, concreteAmounts[tmpIndexes.cpb25]),
				reduce(+, concreteAmounts[tmpIndexes.cpb50]),
				reduce(+, concreteAmounts[tmpIndexes.cpb80]),
				reduce(+, concreteAmounts[tmpIndexes.cpb95]),
				reduce(+, map(x->x.amount,txs[tmpIndexes.cpe100])),
				reduce(+, concreteAmounts[tmpIndexes.wpb10]),
				reduce(+, concreteAmounts[tmpIndexes.wpb25]),
				reduce(+, concreteAmounts[tmpIndexes.wpb50]),
				reduce(+, concreteAmounts[tmpIndexes.wpa80]),
				reduce(+, concreteAmounts[tmpIndexes.wpa95]),
			)
		return ret
		end
	function CalcAddressAccumulation(txs::Vector{TransactionRow})::CellAddressAccumulation
		tsMin = min(txs[1].ts, txs[end].ts)
		tsMax = max(txs[1].ts, txs[end].ts)
		tsMid = round(Int32, (tsMin+tsMax)/2)
		concreteIndexes  = map(x->!x.tagNew,txs)
		ids = map(x->x.addrId, txs[concreteIndexes])
		concreteLastPayed    = map(id->AddressService.GetField(:TimestampLastPayed, id), ids)
		concreteLastReceived = map(id->AddressService.GetField(:TimestampLastReceived, id), ids)
		concreteAmounts      = map(x->x.amount, txs[concreteIndexes])
		concreteAmountsSend  = concreteAmounts .< 0.0
		concreteAmountsBuy   = concreteAmounts .> 0.0
		tmpIndexes = (
			recentD3Sending = map(t->tsMid-t < 3seconds.Day, concreteLastPayed),
			wakeupW1Sending = map(t->tsMid-t > 7seconds.Day, concreteLastPayed),
			wakeupM1Sending = map(t->tsMid-t > seconds.Month, concreteLastPayed),

			recentD3Buying = map(t->tsMid-t < 3seconds.Day, concreteLastReceived),
			wakeupW1Buying = map(t->tsMid-t > 7seconds.Day, concreteLastReceived),
			wakeupM1Buying = map(t->tsMid-t > seconds.Month, concreteLastReceived),

			contiD1Sending = map(t->tsMax-t > seconds.Day, concreteLastReceived) .&& concreteAmountsSend,
			contiD3Sending = map(t->tsMax-t > 3seconds.Day, concreteLastReceived) .&& concreteAmountsSend,
			contiW1Sending = map(t->tsMax-t > 7seconds.Day, concreteLastReceived) .&& concreteAmountsSend,

			contiD1Buying  = map(t->tsMax-t >= seconds.Day, concreteLastPayed) .&& concreteAmountsBuy,
			contiD3Buying  = map(t->tsMax-t > 3seconds.Day, concreteLastPayed) .&& concreteAmountsBuy,
			contiW1Buying  = map(t->tsMax-t > 7seconds.Day, concreteLastPayed) .&& concreteAmountsBuy,
			)
		concreteAmounts = abs.(concreteAmounts)
		ret = CellAddressAccumulation(
				sum(tmpIndexes.recentD3Sending),
				sum(tmpIndexes.wakeupW1Sending),
				sum(tmpIndexes.wakeupM1Sending),
				sum(tmpIndexes.recentD3Buying),
				sum(tmpIndexes.wakeupW1Buying),
				sum(tmpIndexes.wakeupM1Buying),
				sum(tmpIndexes.contiD1Sending),
				sum(tmpIndexes.contiD3Sending),
				sum(tmpIndexes.contiW1Sending),
				sum(tmpIndexes.contiD1Buying),
				sum(tmpIndexes.contiD3Buying),
				sum(tmpIndexes.contiW1Buying),
				
				reduce(+,concreteAmounts[tmpIndexes.recentD3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupW1Sending]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupM1Sending]),
				reduce(+,concreteAmounts[tmpIndexes.recentD3Buying]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupW1Buying]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupM1Buying]),
				reduce(+,concreteAmounts[tmpIndexes.contiD1Sending]),
				reduce(+,concreteAmounts[tmpIndexes.contiD3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.contiW1Sending]),
				reduce(+,concreteAmounts[tmpIndexes.contiD1Buying]),
				reduce(+,concreteAmounts[tmpIndexes.contiD3Buying]),
				reduce(+,concreteAmounts[tmpIndexes.contiW1Buying]),
			)
		return ret
		end
	function CalcAddressSupplier(txs::Vector{TransactionRow})::CellAddressSupplier
		concreteIndexes  = map(x->!x.tagNew && x.amount<0, txs)
		concreteBalances = map(id->abs(AddressService.GetField(:Balance,id)),
			map(x->x.addrId, txs[concreteIndexes])
			)
		concreteAmounts  = abs.(map(x->x.amount, txs[concreteIndexes]))
		sortedBalances = sort(concreteBalances)[1:floor(Int, 0.99*end)]
		ret = CellAddressSupplier(
				sum(sortedBalances) / length(sortedBalances),
				Statistics.std(sortedBalances),
				sortedBalances[floor(Int, 0.2*end)],
				sortedBalances[floor(Int, 0.4*end)],
				sortedBalances[round(Int, 0.5*end)],
				sortedBalances[ceil(Int, 0.6*end)],
				sortedBalances[ceil(Int, 0.8*end)],
				sortedBalances[ceil(Int, 0.95*end)],
				reduce(+, concreteAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.2*end)], concreteBalances)
					]),
				reduce(+, concreteAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.4*end)], concreteBalances)
					]),
				reduce(+, concreteAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.6*end)], concreteBalances)
					]),
				reduce(+, concreteAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.8*end)], concreteBalances)
					]),
				reduce(+, concreteAmounts[
					map(x -> x >= sortedBalances[ceil(Int, 0.95*end)], concreteBalances)
					]),
			)
		return ret
		end
	function CalcAddressUsdtDiff(txs::Vector{TransactionRow})::CellAddressUsdtDiff
		ret = CellAddressUsdtDiff(zeros(length(CellAddressUsdtDiff.types))...)
		concreteIndexes  = map(x->!x.tagNew && x.amount<0, txs)
		for r in txs[concreteIndexes]
			coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, r.ts)
			boughtPrice = AddressService.GetField(:AveragePurchasePrice, r.addrId)
			if isnan(coinPrice) || isnan(boughtPrice) || isnan(r.amount)
				@warn r.addrId
				@show coinPrice
				@show boughtPrice
				@show r.amount
				@warn r
				@warn AddressService.GetRow(r.addrId)[]
			end
			if coinPrice > boughtPrice
				ret.numRealizedProfit += 1
				ret.amountRealizedProfitBillion += Float64(coinPrice-boughtPrice) * abs(r.amount) / 1e9
			else
				ret.numRealizedLoss += 1
				ret.amountRealizedLossBillion += Float64(boughtPrice-coinPrice) * abs(r.amount) / 1e9
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
	mutable struct ResultCalculations
		timestamp::Int32
		# CellAddressComparative
		numTotalActive::Int32
		numTotalRows::Int32
		amountTotalTransfer::Float32
		percentBiasReference::Float32
		percentNumNew::Float32
		percentNumSending::Float32
		percentNumReceiving::Float32
		# CellAddressDirection
		numChargePercentBelow10::Int32
		numChargePercentBelow25::Int32
		numChargePercentBelow50::Int32
		numChargePercentBelow80::Int32
		numChargePercentBelow95::Int32
		numChargePercentEquals100::Int32
		numWithdrawPercentBelow10::Int32
		numWithdrawPercentBelow25::Int32
		numWithdrawPercentBelow50::Int32
		numWithdrawPercentAbove80::Int32
		numWithdrawPercentAbove95::Int32
		amountChargePercentBelow10::Float32
		amountChargePercentBelow25::Float32
		amountChargePercentBelow50::Float32
		amountChargePercentBelow80::Float32
		amountChargePercentBelow95::Float32
		amountChargePercentEquals100::Float32
		amountWithdrawPercentBelow10::Float32
		amountWithdrawPercentBelow25::Float32
		amountWithdrawPercentBelow50::Float32
		amountWithdrawPercentAbove80::Float32
		amountWithdrawPercentAbove95::Float32
		# CellAddressAccumulation
		numRecentD3Sending::Int32
		numWakeupW1Sending::Int32
		numWakeupM1Sending::Int32
		numRecentD3Buying::Int32
		numWakeupW1Buying::Int32
		numWakeupM1Buying::Int32
		numContinuousD1Sending::Int32
		numContinuousD3Sending::Int32
		numContinuousW1Sending::Int32
		numContinuousD1Buying::Int32
		numContinuousD3Buying::Int32
		numContinuousW1Buying::Int32
		amountRecentD3Sending::Float32
		amountWakeupW1Sending::Float32
		amountWakeupM1Sending::Float32
		amountRecentD3Buying::Float32
		amountWakeupW1Buying::Float32
		amountWakeupM1Buying::Float32
		amountContinuousD1Sending::Float32
		amountContinuousD3Sending::Float32
		amountContinuousW1Sending::Float32
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
		balanceSupplierPercent95::Float32
		amountSupplierBalanceBelow20::Float32
		amountSupplierBalanceBelow40::Float32
		amountSupplierBalanceBelow60::Float32
		amountSupplierBalanceBelow80::Float32
		amountSupplierBalanceAbove95::Float32
		# CellAddressUsdtDiff
		numRealizedProfit::Int32
		numRealizedLoss::Int32
		amountRealizedProfitBillion::Float64
		amountRealizedLossBillion::Float64
		end
	function DoCalculations(txs::Vector{TransactionRow}, ts::Int32)::ResultCalculations
		listTask = Vector{Task}(undef,length(Calculations))
		for i in 1:length(Calculations)
			listTask[i] = Threads.@spawn Calculations[i].handler(txs)
		end
		wait.(listTask)
		return ResultCalculations(
				ts,
			# CellAddressComparative
				listTask[1].result.numTotalActive,
				listTask[1].result.numTotalRows,
				listTask[1].result.amountTotalTransfer,
				listTask[1].result.percentBiasReference,
				listTask[1].result.percentNumNew,
				listTask[1].result.percentNumSending,
				listTask[1].result.percentNumReceiving,
			# CellAddressDirection
				listTask[2].result.numChargePercentBelow10,
				listTask[2].result.numChargePercentBelow25,
				listTask[2].result.numChargePercentBelow50,
				listTask[2].result.numChargePercentBelow80,
				listTask[2].result.numChargePercentBelow95,
				listTask[2].result.numChargePercentEquals100,
				listTask[2].result.numWithdrawPercentBelow10,
				listTask[2].result.numWithdrawPercentBelow25,
				listTask[2].result.numWithdrawPercentBelow50,
				listTask[2].result.numWithdrawPercentAbove80,
				listTask[2].result.numWithdrawPercentAbove95,
				listTask[2].result.amountChargePercentBelow10,
				listTask[2].result.amountChargePercentBelow25,
				listTask[2].result.amountChargePercentBelow50,
				listTask[2].result.amountChargePercentBelow80,
				listTask[2].result.amountChargePercentBelow95,
				listTask[2].result.amountChargePercentEquals100,
				listTask[2].result.amountWithdrawPercentBelow10,
				listTask[2].result.amountWithdrawPercentBelow25,
				listTask[2].result.amountWithdrawPercentBelow50,
				listTask[2].result.amountWithdrawPercentAbove80,
				listTask[2].result.amountWithdrawPercentAbove95,
			# CellAddressAccumulation
				listTask[3].result.numRecentD3Sending,
				listTask[3].result.numWakeupW1Sending,
				listTask[3].result.numWakeupM1Sending,
				listTask[3].result.numRecentD3Buying,
				listTask[3].result.numWakeupW1Buying,
				listTask[3].result.numWakeupM1Buying,
				listTask[3].result.numContinuousD1Sending,
				listTask[3].result.numContinuousD3Sending,
				listTask[3].result.numContinuousW1Sending,
				listTask[3].result.numContinuousD1Buying,
				listTask[3].result.numContinuousD3Buying,
				listTask[3].result.numContinuousW1Buying,
				listTask[3].result.amountRecentD3Sending,
				listTask[3].result.amountWakeupW1Sending,
				listTask[3].result.amountWakeupM1Sending,
				listTask[3].result.amountRecentD3Buying,
				listTask[3].result.amountWakeupW1Buying,
				listTask[3].result.amountWakeupM1Buying,
				listTask[3].result.amountContinuousD1Sending,
				listTask[3].result.amountContinuousD3Sending,
				listTask[3].result.amountContinuousW1Sending,
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
				listTask[4].result.balanceSupplierPercent95,
				listTask[4].result.amountSupplierBalanceBelow20,
				listTask[4].result.amountSupplierBalanceBelow40,
				listTask[4].result.amountSupplierBalanceBelow60,
				listTask[4].result.amountSupplierBalanceBelow80,
				listTask[4].result.amountSupplierBalanceAbove95,
			# CellAddressUsdtDiff
				listTask[5].result.numRealizedProfit,
				listTask[5].result.numRealizedLoss,
				listTask[5].result.amountRealizedProfitBillion,
				listTask[5].result.amountRealizedLossBillion,
		)
		end


# Processing
	fromDate = DateTime(2018,1, 1, 0, 0, 0)
	toDate   = DateTime(2021,12,31,23,59,59)
	posStart = SelectPeriod(fromDate, toDate, TxRowsDF.Timestamp)[1]
	# Sum data before, you can save this to a jld2 file
	# we suggest use the start time of market data, 2017
	prog = ProgressMeter.Progress(posStart-2; barlen=64, color=:blue)
	for i in 1:posStart-1
		addrId, amount, ts = TxRowsDF[i,:]
		touch!(TransactionRow(
			addrId, AddressService.isNew(addrId), amount, ts
			))
		next!(prog)
	end
	# now it's time to process real stuff

	nextPosRef   = posStart - 10
	thisPosEnd   = posStart - 10
	thisPosStart = posStart - 10
	resultsLen   = (toDate - fromDate).value / 1000 / seconds.Hour / 3
	resultsLen   = ceil(Int, resultsLen)
	results      = Vector{ResultCalculations}(undef,resultsLen)
	resultCounter= 1
	prog = ProgressMeter.Progress(resultsLen; barlen=49, color=:blue)
	flagTest     = true
	for dt in fromDate:Hour(3):fromDate+Day(100)
		tsStart = dt2unix(dt)
		thisPosStart = findnext(x-> x >= tsStart,
			TxRowsDF.Timestamp, nextPosRef)
		thisPosEnd   = findnext(x-> x > tsStart + 3seconds.Hour,
			TxRowsDF.Timestamp, nextPosRef) - 1
		v = [ TransactionRow(
						TxRowsDF[i,:AddressId],
						AddressService.isNew(TxRowsDF[i,:AddressId]),
						TxRowsDF[i,:Amount],
						TxRowsDF[i,:Timestamp],
					)
					for i in thisPosStart:thisPosEnd
				]
		results[resultCounter] = DoCalculations(v, tsStart)
		resultCounter += 1
		nextPosRef = thisPosEnd + 1
		if !flagTest
			for tr in v
				touch!(tr)
			end
		end
		next!(prog)
	end





# Analyze results
	# you are free to process simple indicators first
	# judge tx direction
	# compare with previous savepoint's account info
	# classify them into groups
	# trigger corresponding recorders
	# we do have snapshot formats of data, try split them into chunks! it'll do good to both you and your deep neural network!
	# ...








































