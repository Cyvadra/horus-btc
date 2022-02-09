using ThreadSafeDicts # private repo
using ProgressMeter
using Dates
using FinanceDB

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
		tplAddrStat = AddressStatistics(zeros(length(AddressStatistics.types))...)
	AddressState  = ThreadSafeDict{UInt32,AddressStatistics}()
	function touch!(addrId::UInt32, ts::Int32, amount::Float64)::Nothing
		AddressState.enabled = false
		coinPrice = FinanceDB.GetDerivativePriceWhen(pairName,ts)
		coinUsdt  = abs(coinPrice * amount)
		if !haskey(AddressState,addrId)
			AddressState[addrId] = deepcopy(tplAddrStat)
			AddressState[addrId].TimestampCreated = ts
			AddressState[addrId].TimestampLastActive = ts
			AddressState[addrId].TimestampLastReceived = ts
			AddressState[addrId].TimestampLastPayed = ts
			AddressState[addrId].AmountIncomeTotal = amount
			AddressState[addrId].NumTxInTotal = 1
			AddressState[addrId].UsdtPayed4Input = coinUsdt
			AddressState[addrId].AveragePurchasePrice = coinPrice
			AddressState[addrId].LastSellPrice = coinPrice
			AddressState[addrId].Balance = amount
			return nothing
		end
		if amount < 0
			AddressState[addrId].AmountExpenseTotal -= amount
			AddressState[addrId].NumTxOutTotal      += 1
			AddressState[addrId].TimestampLastPayed = ts
			AddressState[addrId].UsdtReceived4Output += coinUsdt
			AddressState[addrId].LastSellPrice      = coinPrice
		else
			AddressState[addrId].AmountIncomeTotal  += amount
			AddressState[addrId].NumTxInTotal       += 1
			AddressState[addrId].TimestampLastReceived = ts
			AddressState[addrId].UsdtPayed4Input += coinUsdt
			AddressState[addrId].AveragePurchasePrice = Float32(
				(AddressState[addrId].AveragePurchasePrice * AddressState[addrId].Balance + coinUsdt) / (AddressState[addrId].Balance + amount)
				)
		end
		AddressState[addrId].Balance += amount
		AddressState[addrId].TimestampLastActive = ts
		AddressState[addrId].UsdtNetRealized = AddressState[addrId].UsdtReceived4Output - AddressState[addrId].UsdtPayed4Input
		AddressState[addrId].UsdtNetUnrealized = (coinPrice-AddressState[addrId].AveragePurchasePrice) * AddressState[addrId].Balance
		AddressState.enabled = true
		nothing
		end
	AddressDiffTpl = ThreadSafeDict{UInt32,Float64}()

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
	function CalcAddressComparative(addrIds::Vector{UInt32}, tagNew::Vector{Bool}, amount::Vector{Float64})::CellAddressComparative
		ret = CellAddressComparative(zeros(length(CellAddressComparative.types))...)
		return ret
		end
	function CalcAddressDirection(addrIds::Vector{UInt32}, tagNew::Vector{Bool}, amount::Vector{Float64})::CellAddressDirection
		ret = CellAddressDirection(zeros(length(CellAddressDirection.types))...)
		return ret
		end
	function CalcAddressAccumulation(addrIds::Vector{UInt32}, tagNew::Vector{Bool}, amount::Vector{Float64})::CellAddressAccumulation
		ret = CellAddressAccumulation(zeros(length(CellAddressAccumulation.types))...)
		return ret
		end
	function CalcAddressSupplier(addrIds::Vector{UInt32}, tagNew::Vector{Bool}, amount::Vector{Float64})::CellAddressSupplier
		ret = CellAddressSupplier(zeros(length(CellAddressSupplier.types))...)
		return ret
		end
	function CalcAddressUsdtDiff(addrIds::Vector{UInt32}, tagNew::Vector{Bool}, amount::Vector{Float64})::CellAddressUsdtDiff
		ret = CellAddressUsdtDiff(zeros(length(CellAddressUsdtDiff.types))...)
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



# Processing
	fromDate = DateTime(2018,1, 1, 0, 0, 0)
	toDate   = DateTime(2021,12,31,23,59,59)
	period   = SelectPeriod(fromDate, toDate, TxRowsDF.Timestamp)
	posStart = period[1]
	posEnd   = period[end]
	# Sum data before, you can save this to a jld2 file
	# we suggest use the start time of market data, 2017
	prog = ProgressMeter.Progress(posStart-2)
	AddressState.enabled = false
	for i in 1:posStart-1
		addrId, amount, ts = TxRowsDF[i,:]
		touch!(addrId, ts, amount)
		next!(prog)
	end
	# AddressState.enabled = true
	# now it's time to process real stuff






# Analyze results
	# you are free to process simple indicators first
	# judge tx direction
	# compare with previous savepoint's account info
	# classify them into groups
	# trigger corresponding recorders
	# we do have snapshot formats of data, try split them into chunks! it'll do good to both you and your deep neural network!
	# ...








































