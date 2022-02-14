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

	function touch!(i::Int)::Nothing
		coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[i])
		coinUsdt  = abs(coinPrice * sumAmount[i])
		pos       = sumAddrId[i]
		if sumTagNew[i]
			if sumAmount[i] >= 0
				AddressService.SetField(:TimestampCreated, pos, sumTs[i])
				AddressService.SetField(:TimestampLastActive, pos, sumTs[i])
				AddressService.SetField(:TimestampLastReceived, pos, sumTs[i])
				AddressService.SetField(:TimestampLastPayed, pos, sumTs[i])
				AddressService.SetField(:AmountIncomeTotal, pos, sumAmount[i])
				AddressService.SetField(:AmountExpenseTotal, pos, 0.0)
				AddressService.SetField(:NumTxInTotal, pos, 1)
				AddressService.SetField(:NumTxOutTotal, pos, 0)
				AddressService.SetField(:UsdtPayed4Input, pos, coinUsdt)
				AddressService.SetField(:UsdtReceived4Output, pos, 0.0)
				AddressService.SetField(:AveragePurchasePrice, pos, coinPrice)
				AddressService.SetField(:LastSellPrice, pos, coinPrice)
				AddressService.SetField(:UsdtNetRealized, pos, 0.0)
				AddressService.SetField(:UsdtNetUnrealized, pos, 0.0)
				AddressService.SetField(:Balance, pos, sumAmount[i])
			else
				AddressService.SetField(:TimestampCreated, pos, sumTs[i])
				AddressService.SetField(:TimestampLastActive, pos, sumTs[i])
				AddressService.SetField(:TimestampLastReceived, pos, sumTs[i])
				AddressService.SetField(:TimestampLastPayed, pos, sumTs[i])
				AddressService.SetField(:AmountIncomeTotal, pos, 0.0)
				AddressService.SetField(:AmountExpenseTotal, pos, abs(sumAmount[i]))
				AddressService.SetField(:NumTxInTotal, pos, 0)
				AddressService.SetField(:NumTxOutTotal, pos, 1)
				AddressService.SetField(:UsdtPayed4Input, pos, 0.0)
				AddressService.SetField(:UsdtReceived4Output, pos, coinUsdt)
				AddressService.SetField(:AveragePurchasePrice, pos, coinPrice)
				AddressService.SetField(:LastSellPrice, pos, coinPrice)
				AddressService.SetField(:UsdtNetRealized, pos, coinUsdt)
				AddressService.SetField(:UsdtNetUnrealized, pos, 0.0)
				AddressService.SetField(:Balance, pos, sumAmount[i])
			end
			return nothing
		end
		addrRO = AddressService.GetRow(pos)
		if sumAmount[i] < 0
			AddressService.SetFieldDiff(:AmountExpenseTotal, pos, -sumAmount[i])
			AddressService.SetFieldDiff(:NumTxOutTotal, pos, 1)
			if addrRO.TimestampLastPayed < sumTs[i]
				AddressService.SetField(:TimestampLastPayed, pos, sumTs[i])
			end
			AddressService.SetFieldDiff(:UsdtReceived4Output, pos, coinUsdt)
			AddressService.SetField(:LastSellPrice, pos, coinPrice)
		else
			AddressService.SetFieldDiff(:AmountIncomeTotal, pos, sumAmount[i])
			AddressService.SetFieldDiff(:NumTxInTotal, pos, 1)
			if addrRO.TimestampLastReceived < sumTs[i]
				AddressService.SetField(:TimestampLastReceived, pos, sumTs[i])
			end
			AddressService.SetFieldDiff(:UsdtPayed4Input, pos, coinUsdt)
			if addrRO.Balance + sumAmount[i] > 1e-9
				AddressService.SetField(:AveragePurchasePrice, pos,
					(coinUsdt + addrRO.AveragePurchasePrice * addrRO.Balance) / (addrRO.Balance + sumAmount[i]) )
			end
		end
		if addrRO.Balance < 0 && addrRO.TimestampCreated > sumTs[i]
			AddressService.SetField(:TimestampCreated, pos, sumTs[i])
		end
		if addrRO.TimestampLastActive < sumTs[i]
			AddressService.SetField(:TimestampLastActive, pos, sumTs[i])
		end
		AddressService.SetFieldDiff(:Balance, pos, sumAmount[i])
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
	function DoCalculations(fromN::Int, toN::Int, ts::Int32)::ResultCalculations
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
	# prog = ProgressMeter.Progress(posStart-2; barlen=64, color=:blue)
	# for i in 1:posStart-1
	# 	addrId, amount, ts = TxRowsDF[i,:]
	# 	touch!(Ref(TransactionRow(
	# 		addrId, AddressService.isNew(addrId), amount, ts
	# 		)))
	# 	next!(prog)
	# end
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
	thisPosEnd   = posStart - 10
	thisPosStart = posStart - 10
	resultsLen   = (toDate - fromDate).value / 1000 / seconds.Hour / 3
	resultsLen   = ceil(Int, resultsLen)
	results      = Vector{ResultCalculations}(undef,resultsLen)
	resultCounter= 1
	prog = ProgressMeter.Progress(resultsLen; barlen=49, color=:blue)
	for dt in fromDate:Hour(3):toDate
		tsStart = dt2unix(dt)
		thisPosStart = findnext(x-> x >= tsStart,
			sumTs, nextPosRef)
		thisPosEnd   = findnext(x-> x > tsStart + 3seconds.Hour,
			sumTs, nextPosRef) - 1
		lenTxs = thisPosEnd - thisPosStart + 1
		for i in 1:lenTxs
			sumTagNew[thisPosStart+i-1] = AddressService.isNew(sumAddrId[thisPosStart+i-1])
		end
		results[resultCounter] = DoCalculations(thisPosStart, thisPosEnd, tsStart)
		resultCounter += 1
		nextPosRef = thisPosEnd + 1
		for i in 1:lenTxs
			touch!(thisPosStart+i-1)
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








































