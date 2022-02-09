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
		if !haskey(AddressState,addrId)
			AddressState[addrId] = deepcopy(tplAddrStat)
			AddressState[addrId].TimestampCreated = ts
		end
		AddressState.enabled = false
		coinPrice = FinanceDB.GetDerivativePriceWhen(pairName,ts)
		coinUsdt  = abs(coinPrice * amount)
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
		AmountInProfitRealized::Float64
		NumInProfitUnrealized::Int64
		AmountInProfitUnrealized::Float64
		# in loss
		NumInLossRealized::Int64
		AmountInLossRealized::Float64
		NumInLossUnrealized::Int64
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
		description::String
		handler::Function
		end
	Calculations = CalcCell[]
	mutable struct CellAddressComparative
		numTotalActive::Int32
		amountTotalTransfer::Float64
		percentNumNew::Float32
		percentNumSending::Float32
		percentNumReceiving::Float32
		end
	mutable struct CellAddressBehavior
		# charge / withdraw
		numChargePercentBelow25::Int32
		numChargePercentBelow50::Int32
		numChargePercentBelow80::Int32
		numChargePercentEquals100::Int32
		numWithdrawPercentBelow50::Int32
		numWithdrawPercentAbove80::Int32
		numWithdrawPercentEquals100::Int32
		amountChargePercentBelow25::Float32
		amountChargePercentBelow50::Float32
		amountChargePercentBelow80::Float32
		amountChargePercentEquals100::Float32
		amountWithdrawPercentBelow50::Float32
		amountWithdrawPercentAbove80::Float32
		amountWithdrawPercentEquals100::Float32
		# wakeup / accumulation
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





# Runtime Statistics
	mutable struct PeriodStat
		timestamp::Int32
	# CellAddressActivity # T3 
		numNew::Int32
		numChargePercentAbove50::Int32
		numChargePercentAbove75::Int32
		numWithdrawPercentAbove50::Int32
		numWithdrawPercentAbove75::Int32
		numSending::Int32
		numReceiving::Int32
		numRecentM1Sending::Int32
		numRecentM1Receiving::Int32
		numTotalActive::Int32
	# CellAddressSupply # T1
		# of all inputs, how much balance did they have before
		supplierBalanceMicro::Int32
		supplierBalance0001::Int32
		supplierBalance001::Int32
		supplierBalance01::Int32
		supplierBalance1::Int32
		supplierBalance10::Int32
		supplierBalance100::Int32
		supplierBalance1k::Int32
		supplierBalance10k::Int32
		supplierBalance50k::Int32
		supplierBalanceMore::Int32
		supplierBalanceMicroAmount::Float64
		supplierBalance0001Amount::Float64
		supplierBalance001Amount::Float64
		supplierBalance01Amount::Float64
		supplierBalance1Amount::Float64
		supplierBalance10Amount::Float64
		supplierBalance100Amount::Float64
		supplierBalance1kAmount::Float64
		supplierBalance10kAmount::Float64
		supplierBalance50kAmount::Float64
		supplierBalanceMoreAmount::Float64
		wakeupAmountM1Sending::Float64
		wakeupAmountM1Receiving::Float64
		wakeupAmountM3Sending::Float64
		wakeupAmountM3Receiving::Float64
		# those who transferred 75%+ of balance
		supplierBreakMicro::Int32
		supplierBreak0001::Int32
		supplierBreak001::Int32
		supplierBreak01::Int32
		supplierBreak1::Int32
		supplierBreak10::Int32
		supplierBreak100::Int32
		supplierBreak1k::Int32
		supplierBreak10k::Int32
		supplierBreak50k::Int32
		supplierBreakMore::Int32
	# CellAddressBalanceDiff # T2
		numBalanceNonZero::Int32 # not implemented
		numBalanceDiffMicro::Int32
		numBalanceDiff0001::Int32
		numBalanceDiff001::Int32
		numBalanceDiff01::Int32
		numBalanceDiff1::Int32
		numBalanceDiff10::Int32
		numBalanceDiff100::Int32
		numBalanceDiff1k::Int32
		numBalanceDiff10k::Int32
		numBalanceDiff50k::Int32
	end
	tplPeriodStat = PeriodStat(zeros(length(PeriodStat.types))...)


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
	results = Vector{PeriodStat}()
	ProcessPeriods!(fromDate, toDate, Hour(12), Ref(results))

# Analyze results
	# you are free to process simple indicators first
	# judge tx direction
	# compare with previous savepoint's account info
	# classify them into groups
	# trigger corresponding recorders
	# we do have snapshot formats of data, try split them into chunks! it'll do good to both you and your deep neural network!
	# ...








































