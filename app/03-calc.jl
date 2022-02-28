using ProgressMeter
using Dates
using Statistics
# private repos
using FinanceDB
using ThreadSafeDicts
using AddressService

@show Threads.nthreads()
include("./02-loadmmap.jl")
AddressService.Open()
MmapDB.Init("/mnt/data/tmp")

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

	function touch!(fromI::Int, toI::Int)::Nothing
		coinPrice = 100.0
		coinUsdt  = 1000.0
		pos = 1
		for _ind in fromI:toI
			coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[_ind])
			coinUsdt  = abs(coinPrice * sumAmount[_ind])
			pos       = sumAddrId[_ind]
			if sumTagNew[_ind]
				if sumAmount[_ind] >= 0
					AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
					AddressService.SetFieldAmountIncomeTotal(pos, sumAmount[_ind])
					AddressService.SetFieldAmountExpenseTotal(pos, 0.0)
					AddressService.SetFieldNumTxInTotal(pos, 1)
					AddressService.SetFieldNumTxOutTotal(pos, 0)
					AddressService.SetFieldUsdtPayed4Input(pos, coinUsdt)
					AddressService.SetFieldUsdtReceived4Output(pos, 0.0)
					AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
					AddressService.SetFieldLastSellPrice(pos, coinPrice)
					AddressService.SetFieldUsdtNetRealized(pos, 0.0)
					AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
					AddressService.SetFieldBalance(pos, sumAmount[_ind])
				else
					AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
					AddressService.SetFieldAmountIncomeTotal(pos, 0.0)
					AddressService.SetFieldAmountExpenseTotal(pos, abs(sumAmount[_ind]))
					AddressService.SetFieldNumTxInTotal(pos, 0)
					AddressService.SetFieldNumTxOutTotal(pos, 1)
					AddressService.SetFieldUsdtPayed4Input(pos, 0.0)
					AddressService.SetFieldUsdtReceived4Output(pos, coinUsdt)
					AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
					AddressService.SetFieldLastSellPrice(pos, coinPrice)
					AddressService.SetFieldUsdtNetRealized(pos, coinUsdt)
					AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
					AddressService.SetFieldBalance(pos, sumAmount[_ind])
				end
				continue
			end
			tmpBalance = AddressService.GetFieldBalance(pos)
			if sumAmount[_ind] < 0
				AddressService.SetFieldDiffAmountExpenseTotal(pos, -sumAmount[_ind])
				AddressService.SetFieldDiffNumTxOutTotal(pos, 1)
				if AddressService.GetFieldTimestampLastPayed(pos) < sumTs[_ind]
					AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				end
				AddressService.SetFieldDiffUsdtReceived4Output(pos, coinUsdt)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
			else
				AddressService.SetFieldDiffAmountIncomeTotal(pos, sumAmount[_ind])
				AddressService.SetFieldDiffNumTxInTotal(pos, 1)
				if AddressService.GetFieldTimestampLastReceived(pos) < sumTs[_ind]
					AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				end
				AddressService.SetFieldDiffUsdtPayed4Input(pos, coinUsdt)
				if tmpBalance > 1e-9
					AddressService.SetFieldAveragePurchasePrice(pos,
						(coinUsdt + AddressService.GetFieldAveragePurchasePrice(pos) * tmpBalance) / (tmpBalance + sumAmount[_ind]) )
				else
					AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				end
			end
			if tmpBalance < 0 && AddressService.GetFieldTimestampCreated(pos) > sumTs[_ind]
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
			end
			if AddressService.GetFieldTimestampLastActive(pos) < sumTs[_ind]
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
			end
			AddressService.SetFieldDiffBalance(pos, sumAmount[_ind])
			AddressService.SetFieldUsdtNetRealized(pos,
				 AddressService.GetFieldUsdtReceived4Output(pos) - AddressService.GetFieldUsdtPayed4Input(pos)
				 )
			AddressService.SetFieldUsdtNetUnrealized(pos,
				 ( coinPrice - AddressService.GetFieldAveragePurchasePrice(pos) )
				 * AddressService.GetFieldBalance(pos)
				 )
		end
		return nothing
		end
	function touch!(_ind::Int)::Nothing
		coinPrice = 100.0
		coinUsdt  = 1000.0
		pos = 1
		coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[_ind])
		coinUsdt  = abs(coinPrice * sumAmount[_ind])
		pos       = sumAddrId[_ind]
		if sumTagNew[_ind]
			if sumAmount[_ind] >= 0
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, sumAmount[_ind])
				AddressService.SetFieldAmountExpenseTotal(pos, 0.0)
				AddressService.SetFieldNumTxInTotal(pos, 1)
				AddressService.SetFieldNumTxOutTotal(pos, 0)
				AddressService.SetFieldUsdtPayed4Input(pos, coinUsdt)
				AddressService.SetFieldUsdtReceived4Output(pos, 0.0)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, 0.0)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			else
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, 0.0)
				AddressService.SetFieldAmountExpenseTotal(pos, abs(sumAmount[_ind]))
				AddressService.SetFieldNumTxInTotal(pos, 0)
				AddressService.SetFieldNumTxOutTotal(pos, 1)
				AddressService.SetFieldUsdtPayed4Input(pos, 0.0)
				AddressService.SetFieldUsdtReceived4Output(pos, coinUsdt)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, coinUsdt)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			end
			return nothing
		end
		tmpBalance = AddressService.GetFieldBalance(pos)
		if sumAmount[_ind] < 0
			AddressService.SetFieldDiffAmountExpenseTotal(pos, -sumAmount[_ind])
			AddressService.SetFieldDiffNumTxOutTotal(pos, 1)
			if AddressService.GetFieldTimestampLastPayed(pos) < sumTs[_ind]
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
			end
			AddressService.SetFieldDiffUsdtReceived4Output(pos, coinUsdt)
			AddressService.SetFieldLastSellPrice(pos, coinPrice)
		else
			AddressService.SetFieldDiffAmountIncomeTotal(pos, sumAmount[_ind])
			AddressService.SetFieldDiffNumTxInTotal(pos, 1)
			if AddressService.GetFieldTimestampLastReceived(pos) < sumTs[_ind]
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
			end
			AddressService.SetFieldDiffUsdtPayed4Input(pos, coinUsdt)
			if tmpBalance > 1e-9
				AddressService.SetFieldAveragePurchasePrice(pos,
					(coinUsdt + AddressService.GetFieldAveragePurchasePrice(pos) * tmpBalance) / (tmpBalance + sumAmount[_ind]) )
			else
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
			end
		end
		if tmpBalance < 0 && AddressService.GetFieldTimestampCreated(pos) > sumTs[_ind]
			AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
		end
		if AddressService.GetFieldTimestampLastActive(pos) < sumTs[_ind]
			AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
		end
		AddressService.SetFieldDiffBalance(pos, sumAmount[_ind])
		AddressService.SetFieldUsdtNetRealized(pos,
			 AddressService.GetFieldUsdtReceived4Output(pos) - AddressService.GetFieldUsdtPayed4Input(pos)
			 )
		AddressService.SetFieldUsdtNetUnrealized(pos,
			 ( coinPrice - AddressService.GetFieldAveragePurchasePrice(pos) )
			 * AddressService.GetFieldBalance(pos)
			 )
		return nothing
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
	function CalcAddressComparative(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressComparative
		_len = length(cacheTs[])
		biasAmount = sum(cacheAmount[])
		estAmount  = (sum(abs.(cacheAmount[])) - biasAmount) / 2
		numOutput  = sum(cacheAmount[] .< 0)
		numInput   = _len - numOutput
		ret = CellAddressComparative(
				length( unique(cacheAddrId[]) ),
				_len,
				estAmount,
				biasAmount / estAmount,
				length(unique(
						cacheAddrId[][ cacheTagNew[] ]
					)) / _len,
				numOutput / _len,
				numInput / _len,
			)
		return ret
		end
	function CalcAddressDirection(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressDirection
		concreteIndexes  = map(x->!x, cacheTagNew[])
		concreteBalances = AddressService.GetField(:Balance,
				cacheAddrId[][ concreteIndexes ]
			)
		concretePercents = cacheAmount[][ concreteIndexes ] ./ concreteBalances
		concreteAmounts  = abs.( cacheAmount[][ concreteIndexes ] )
		tmpIndexes = (
			cpb10 = map(x-> 0.00 < x <= 0.10, concretePercents),
			cpb25 = map(x-> 0.10 < x <= 0.25, concretePercents),
			cpb50 = map(x-> 0.25 < x <= 0.50, concretePercents),
			cpb80 = map(x-> 0.50 < x <= 0.80, concretePercents),
			cpb95 = map(x-> 0.80 < x <= 0.95, concretePercents),
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
				sum(cacheTagNew[]),
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
				reduce(+, cacheAmount[][ cacheTagNew[] ]),
				reduce(+, concreteAmounts[tmpIndexes.wpb10]),
				reduce(+, concreteAmounts[tmpIndexes.wpb25]),
				reduce(+, concreteAmounts[tmpIndexes.wpb50]),
				reduce(+, concreteAmounts[tmpIndexes.wpa80]),
				reduce(+, concreteAmounts[tmpIndexes.wpa95]),
			)
		return ret
		end
	function CalcAddressAccumulation(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressAccumulation
		tsMin = min( cacheTs[][1], cacheTs[][end] )
		tsMax = max( cacheTs[][1], cacheTs[][end] )
		tsMid = round(Int32, (tsMin+tsMax)/2)
		concreteIndexes  = map(x->!x, cacheTagNew[])
		ids = cacheAddrId[][concreteIndexes]
		concreteLastPayed    = AddressService.GetField(:TimestampLastPayed, ids)
		concreteLastReceived = AddressService.GetField(:TimestampLastReceived, ids)
		concreteAmounts      = cacheAmount[][concreteIndexes]
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
	function CalcAddressSupplier(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressSupplier
		concreteIndexes  = map(x->!x, cacheTagNew[])
		concreteIndexes  = concreteIndexes .&& (cacheAmount[] .< 0.0)
		concreteBalances = abs.(AddressService.GetField(:Balance,
			cacheAddrId[][ concreteIndexes ]
			))
		concreteAmounts  = abs.(cacheAmount[][ concreteIndexes ])
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
	function CalcAddressUsdtDiff(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressUsdtDiff
		ret = CellAddressUsdtDiff(zeros(length(CellAddressUsdtDiff.types))...)
		concreteIndexes  = map(x->!x, cacheTagNew[])
		concreteIndexes  = concreteIndexes .&& (cacheAmount[] .< 0.0)
		_indexes = collect(1:length(concreteIndexes))[concreteIndexes]
		for i in _indexes
			coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, cacheTs[][i])
			boughtPrice = AddressService.GetField(:AveragePurchasePrice, cacheAddrId[][i])
			if coinPrice > boughtPrice
				ret.numRealizedProfit += 1
				ret.amountRealizedProfitBillion += Float64(coinPrice-boughtPrice) * abs(cacheAmount[][i]) / 1e9
			else
				ret.numRealizedLoss += 1
				ret.amountRealizedLossBillion += Float64(boughtPrice-coinPrice) * abs(cacheAmount[][i]) / 1e9
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
	function DoCalculations!(fromN::Int, toN::Int, tpl::Base.RefValue{ResultCalculations})::Nothing
		cacheAddrId = sumAddrId[fromN:toN]
		cacheTagNew = sumTagNew[fromN:toN]
		cacheAmount = sumAmount[fromN:toN]
		cacheTs     = sumTs[fromN:toN]
		listTask = Vector{Task}(undef,length(Calculations))
		for i in 1:length(Calculations)
			listTask[i] = Threads.@spawn Calculations[i].handler(
					Ref(cacheAddrId),
					Ref(cacheTagNew),
					Ref(cacheAmount),
					Ref(cacheTs),
				)
		end
		wait.(listTask)
		tpl.x.numTotalActive += listTask[1].result.numTotalActive
		tpl.x.numTotalRows += listTask[1].result.numTotalRows
		tpl.x.amountTotalTransfer += listTask[1].result.amountTotalTransfer
		tpl.x.percentBiasReference += listTask[1].result.percentBiasReference
		tpl.x.percentNumNew += listTask[1].result.percentNumNew
		tpl.x.percentNumSending += listTask[1].result.percentNumSending
		tpl.x.percentNumReceiving += listTask[1].result.percentNumReceiving
		tpl.x.numChargePercentBelow10 += listTask[2].result.numChargePercentBelow10
		tpl.x.numChargePercentBelow25 += listTask[2].result.numChargePercentBelow25
		tpl.x.numChargePercentBelow50 += listTask[2].result.numChargePercentBelow50
		tpl.x.numChargePercentBelow80 += listTask[2].result.numChargePercentBelow80
		tpl.x.numChargePercentBelow95 += listTask[2].result.numChargePercentBelow95
		tpl.x.numChargePercentEquals100 += listTask[2].result.numChargePercentEquals100
		tpl.x.numWithdrawPercentBelow10 += listTask[2].result.numWithdrawPercentBelow10
		tpl.x.numWithdrawPercentBelow25 += listTask[2].result.numWithdrawPercentBelow25
		tpl.x.numWithdrawPercentBelow50 += listTask[2].result.numWithdrawPercentBelow50
		tpl.x.numWithdrawPercentAbove80 += listTask[2].result.numWithdrawPercentAbove80
		tpl.x.numWithdrawPercentAbove95 += listTask[2].result.numWithdrawPercentAbove95
		tpl.x.amountChargePercentBelow10 += listTask[2].result.amountChargePercentBelow10
		tpl.x.amountChargePercentBelow25 += listTask[2].result.amountChargePercentBelow25
		tpl.x.amountChargePercentBelow50 += listTask[2].result.amountChargePercentBelow50
		tpl.x.amountChargePercentBelow80 += listTask[2].result.amountChargePercentBelow80
		tpl.x.amountChargePercentBelow95 += listTask[2].result.amountChargePercentBelow95
		tpl.x.amountChargePercentEquals100 += listTask[2].result.amountChargePercentEquals100
		tpl.x.amountWithdrawPercentBelow10 += listTask[2].result.amountWithdrawPercentBelow10
		tpl.x.amountWithdrawPercentBelow25 += listTask[2].result.amountWithdrawPercentBelow25
		tpl.x.amountWithdrawPercentBelow50 += listTask[2].result.amountWithdrawPercentBelow50
		tpl.x.amountWithdrawPercentAbove80 += listTask[2].result.amountWithdrawPercentAbove80
		tpl.x.amountWithdrawPercentAbove95 += listTask[2].result.amountWithdrawPercentAbove95
		tpl.x.numRecentD3Sending += listTask[3].result.numRecentD3Sending
		tpl.x.numWakeupW1Sending += listTask[3].result.numWakeupW1Sending
		tpl.x.numWakeupM1Sending += listTask[3].result.numWakeupM1Sending
		tpl.x.numRecentD3Buying += listTask[3].result.numRecentD3Buying
		tpl.x.numWakeupW1Buying += listTask[3].result.numWakeupW1Buying
		tpl.x.numWakeupM1Buying += listTask[3].result.numWakeupM1Buying
		tpl.x.numContinuousD1Sending += listTask[3].result.numContinuousD1Sending
		tpl.x.numContinuousD3Sending += listTask[3].result.numContinuousD3Sending
		tpl.x.numContinuousW1Sending += listTask[3].result.numContinuousW1Sending
		tpl.x.numContinuousD1Buying += listTask[3].result.numContinuousD1Buying
		tpl.x.numContinuousD3Buying += listTask[3].result.numContinuousD3Buying
		tpl.x.numContinuousW1Buying += listTask[3].result.numContinuousW1Buying
		tpl.x.amountRecentD3Sending += listTask[3].result.amountRecentD3Sending
		tpl.x.amountWakeupW1Sending += listTask[3].result.amountWakeupW1Sending
		tpl.x.amountWakeupM1Sending += listTask[3].result.amountWakeupM1Sending
		tpl.x.amountRecentD3Buying += listTask[3].result.amountRecentD3Buying
		tpl.x.amountWakeupW1Buying += listTask[3].result.amountWakeupW1Buying
		tpl.x.amountWakeupM1Buying += listTask[3].result.amountWakeupM1Buying
		tpl.x.amountContinuousD1Sending += listTask[3].result.amountContinuousD1Sending
		tpl.x.amountContinuousD3Sending += listTask[3].result.amountContinuousD3Sending
		tpl.x.amountContinuousW1Sending += listTask[3].result.amountContinuousW1Sending
		tpl.x.amountContinuousD1Buying += listTask[3].result.amountContinuousD1Buying
		tpl.x.amountContinuousD3Buying += listTask[3].result.amountContinuousD3Buying
		tpl.x.amountContinuousW1Buying += listTask[3].result.amountContinuousW1Buying
		tpl.x.balanceSupplierMean += listTask[4].result.balanceSupplierMean
		tpl.x.balanceSupplierStd += listTask[4].result.balanceSupplierStd
		tpl.x.balanceSupplierPercent20 += listTask[4].result.balanceSupplierPercent20
		tpl.x.balanceSupplierPercent40 += listTask[4].result.balanceSupplierPercent40
		tpl.x.balanceSupplierMiddle += listTask[4].result.balanceSupplierMiddle
		tpl.x.balanceSupplierPercent60 += listTask[4].result.balanceSupplierPercent60
		tpl.x.balanceSupplierPercent80 += listTask[4].result.balanceSupplierPercent80
		tpl.x.balanceSupplierPercent95 += listTask[4].result.balanceSupplierPercent95
		tpl.x.amountSupplierBalanceBelow20 += listTask[4].result.amountSupplierBalanceBelow20
		tpl.x.amountSupplierBalanceBelow40 += listTask[4].result.amountSupplierBalanceBelow40
		tpl.x.amountSupplierBalanceBelow60 += listTask[4].result.amountSupplierBalanceBelow60
		tpl.x.amountSupplierBalanceBelow80 += listTask[4].result.amountSupplierBalanceBelow80
		tpl.x.amountSupplierBalanceAbove95 += listTask[4].result.amountSupplierBalanceAbove95
		tpl.x.numRealizedProfit += listTask[5].result.numRealizedProfit
		tpl.x.numRealizedLoss += listTask[5].result.numRealizedLoss
		tpl.x.amountRealizedProfitBillion += listTask[5].result.amountRealizedProfitBillion
		tpl.x.amountRealizedLossBillion += listTask[5].result.amountRealizedLossBillion
		return nothing
		end


# Processing
	fromDate = DateTime(2018,1, 1, 0, 0, 0)
	toDate   = DateTime(2021,12,24,23,59,59)
	posStart = SelectPeriod(fromDate, toDate, TxRowsDF.Timestamp)[1]
	# Sum data before, you can save this to a jld2 file
	# we suggest use the start time of market data, 2017
	# prog = ProgressMeter.Progress(posStart-2; barlen=64, color=:blue)

	# now it's time to process real stuff
	tmpLen = nrow(TxRowsDF)
	# pre alloc mem
	sumAddrId = deepcopy(TxRowsDF[posStart:tmpLen, :AddressId])
	sumTagNew = fill(true, tmpLen - posStart + 1)
	sumAmount = deepcopy(TxRowsDF[posStart:tmpLen, :Amount])
	sumTs     = deepcopy(TxRowsDF[posStart:tmpLen, :Timestamp])

	TxRowsDF = nothing
	@show now()
	@info "collecting varinfo"
	@show varinfo(r"TxRows")
	@show now()
	@info "gc complete"

	# go
	nextPosRef   = 1
	thisPosStart = 1
	thisPosEnd   = 1
	resLen       = ceil(Int, (toDate - fromDate).value / 1000 / 3600 / 3)
	TableResultCalculations = MmapDB.GenerateCode(ResultCalculations)
	TableResultCalculations.Create!(resLen)
	resCounter = 1
	barLen   = findlast(x->x<=dt2unix(toDate), sumTs) - findfirst(x->x>=dt2unix(fromDate), sumTs) + 1
	prog     = ProgressMeter.Progress(barLen; barlen=36, color=:blue)
	for dt in fromDate:Hour(3):toDate
		if isfile("/tmp/JULIA_EMERGENCY_STOP")
			@show dt
			break
		end
		tsStart = dt2unix(dt)
		thisPosStart = findnext(x-> x >= tsStart, sumTs, nextPosRef)
		thisPosEnd   = findnext(x-> x > tsStart + 3seconds.Hour, sumTs, nextPosRef) - 1
		lenTxs = thisPosEnd - thisPosStart + 1
		for i in 1:lenTxs
			_ind = thisPosStart+i-1
			sumTagNew[_ind] = AddressService.isNew(sumAddrId[_ind])
		end
		resultTpl = ResultCalculations(zeros(length(ResultCalculations.types))...)
		resultTpl.timestamp = tsStart
		lastI = 0
		# calc loop, in bach
		t = @timed DoCalculations!(thisPosStart, thisPosEnd, Ref(resultTpl))
		println()
		@info "Calculation Time: $(Float16(t.time))s, gc $(Float16(t.gctime)), $(Float32(t.bytes / 1024^3))GB"
		t = @timed touch!(thisPosStart, thisPosEnd)
		@info "Calculation Time: $(Float16(t.time))s, gc $(Float16(t.gctime)), $(Float32(t.bytes / 1024^3))GB"
		println()
		# debug
		if isinf(resultTpl.amountRealizedProfitBillion) || isnan(resultTpl.amountRealizedProfitBillion)
			@warn "inf detected"
			@show fromDate
			@show toDate
			@show thisPosStart
			@show thisPosEnd
			break
		end
		TableResultCalculations.SetRow(resCounter, resultTpl)
		resCounter += 1
		nextPosRef = thisPosEnd + 1
		next!( prog; step=(thisPosEnd - thisPosStart + 1) )
	end







# Analyze results
	# you are free to process simple indicators first
	# judge tx direction
	# compare with previous savepoint's account info
	# classify them into groups
	# trigger corresponding recorders
	# we do have snapshot formats of data, try split them into chunks! it'll do good to both you and your deep neural network!
	# ...








































