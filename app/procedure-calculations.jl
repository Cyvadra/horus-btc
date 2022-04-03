
	AddressService
	GetBTCPriceWhen
	ResultCalculations
	using Statistics

	# sumAddrId
	# sumTagNew
	# sumAmount
	# sumTs

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
	function safe_sum(arr)
		if isempty(arr)
			return 0
		end
		return sum(arr)
		end

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
		estAmount  = (safe_sum(abs.(cacheAmount[])) - biasAmount) / 2
		numOutput  = sum(cacheAmount[] .< 0)
		numInput   = _len - numOutput
		ret = CellAddressComparative(
				length( unique(cacheAddrId[]) ),
				_len,
				estAmount,
				iszero(estAmount) ? 0 : biasAmount / estAmount,
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
		concreteBalances = AddressService.GetFieldBalance(cacheAddrId[][ concreteIndexes ])
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
				safe_sum(tmpIndexes.cpb10),
				safe_sum(tmpIndexes.cpb25),
				safe_sum(tmpIndexes.cpb50),
				safe_sum(tmpIndexes.cpb80),
				safe_sum(tmpIndexes.cpb95),
				safe_sum(cacheTagNew[]),
				safe_sum(tmpIndexes.wpb10),
				safe_sum(tmpIndexes.wpb25),
				safe_sum(tmpIndexes.wpb50),
				safe_sum(tmpIndexes.wpa80),
				safe_sum(tmpIndexes.wpa95),

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
		concreteLastPayed    = AddressService.GetFieldTimestampLastPayed(ids)
		concreteLastReceived = AddressService.GetFieldTimestampLastReceived(ids)
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
				safe_sum(tmpIndexes.recentD3Sending),
				safe_sum(tmpIndexes.wakeupW1Sending),
				safe_sum(tmpIndexes.wakeupM1Sending),
				safe_sum(tmpIndexes.recentD3Buying),
				safe_sum(tmpIndexes.wakeupW1Buying),
				safe_sum(tmpIndexes.wakeupM1Buying),
				safe_sum(tmpIndexes.contiD1Sending),
				safe_sum(tmpIndexes.contiD3Sending),
				safe_sum(tmpIndexes.contiW1Sending),
				safe_sum(tmpIndexes.contiD1Buying),
				safe_sum(tmpIndexes.contiD3Buying),
				safe_sum(tmpIndexes.contiW1Buying),
				
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
		concreteBalances = abs.(AddressService.GetFieldBalance(
			cacheAddrId[][ concreteIndexes ]))
		concreteAmounts  = abs.(cacheAmount[][ concreteIndexes ])
		if isempty(concreteBalances)
			concreteBalances = zeros(10)
			concreteAmounts  = zeros(10)
		end
		sortedBalances = sort(concreteBalances)[1:floor(Int, 0.99*end)]
		ret = CellAddressSupplier(
				sum(sortedBalances) / length(sortedBalances),
				Statistics.std(sortedBalances),
				sortedBalances[floor(Int, 0.2*end)],
				sortedBalances[floor(Int, 0.4*end)],
				sortedBalances[floor(Int, 0.5*end)],
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
			coinPrice = GetBTCPriceWhen(cacheTs[][i])
			boughtPrice = AddressService.GetFieldAveragePurchasePrice(cacheAddrId[][i])
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

	function DoCalculations(cacheAddrId::Vector{UInt32}, cacheTagNew::Vector{Bool}, cacheAmount::Vector{Float64}, cacheTs::Vector{Int32})::ResultCalculations
		listTask = Vector{Task}(undef,length(Calculations))
		for i in 1:length(Calculations)
			listTask[i] = Threads.@spawn Calculations[i].handler(
					Ref(cacheAddrId),
					Ref(cacheTagNew),
					Ref(cacheAmount),
					Ref(cacheTs),
				)
		end
		ret = ResultCalculations(zeros(length(ResultCalculations.types))...)
		wait.(listTask)
		ret.numTotalActive += listTask[1].result.numTotalActive
		ret.numTotalRows += listTask[1].result.numTotalRows
		ret.amountTotalTransfer += listTask[1].result.amountTotalTransfer
		ret.percentBiasReference += listTask[1].result.percentBiasReference
		ret.percentNumNew += listTask[1].result.percentNumNew
		ret.percentNumSending += listTask[1].result.percentNumSending
		ret.percentNumReceiving += listTask[1].result.percentNumReceiving
		ret.numChargePercentBelow10 += listTask[2].result.numChargePercentBelow10
		ret.numChargePercentBelow25 += listTask[2].result.numChargePercentBelow25
		ret.numChargePercentBelow50 += listTask[2].result.numChargePercentBelow50
		ret.numChargePercentBelow80 += listTask[2].result.numChargePercentBelow80
		ret.numChargePercentBelow95 += listTask[2].result.numChargePercentBelow95
		ret.numChargePercentEquals100 += listTask[2].result.numChargePercentEquals100
		ret.numWithdrawPercentBelow10 += listTask[2].result.numWithdrawPercentBelow10
		ret.numWithdrawPercentBelow25 += listTask[2].result.numWithdrawPercentBelow25
		ret.numWithdrawPercentBelow50 += listTask[2].result.numWithdrawPercentBelow50
		ret.numWithdrawPercentAbove80 += listTask[2].result.numWithdrawPercentAbove80
		ret.numWithdrawPercentAbove95 += listTask[2].result.numWithdrawPercentAbove95
		ret.amountChargePercentBelow10 += listTask[2].result.amountChargePercentBelow10
		ret.amountChargePercentBelow25 += listTask[2].result.amountChargePercentBelow25
		ret.amountChargePercentBelow50 += listTask[2].result.amountChargePercentBelow50
		ret.amountChargePercentBelow80 += listTask[2].result.amountChargePercentBelow80
		ret.amountChargePercentBelow95 += listTask[2].result.amountChargePercentBelow95
		ret.amountChargePercentEquals100 += listTask[2].result.amountChargePercentEquals100
		ret.amountWithdrawPercentBelow10 += listTask[2].result.amountWithdrawPercentBelow10
		ret.amountWithdrawPercentBelow25 += listTask[2].result.amountWithdrawPercentBelow25
		ret.amountWithdrawPercentBelow50 += listTask[2].result.amountWithdrawPercentBelow50
		ret.amountWithdrawPercentAbove80 += listTask[2].result.amountWithdrawPercentAbove80
		ret.amountWithdrawPercentAbove95 += listTask[2].result.amountWithdrawPercentAbove95
		ret.numRecentD3Sending += listTask[3].result.numRecentD3Sending
		ret.numWakeupW1Sending += listTask[3].result.numWakeupW1Sending
		ret.numWakeupM1Sending += listTask[3].result.numWakeupM1Sending
		ret.numRecentD3Buying += listTask[3].result.numRecentD3Buying
		ret.numWakeupW1Buying += listTask[3].result.numWakeupW1Buying
		ret.numWakeupM1Buying += listTask[3].result.numWakeupM1Buying
		ret.numContinuousD1Sending += listTask[3].result.numContinuousD1Sending
		ret.numContinuousD3Sending += listTask[3].result.numContinuousD3Sending
		ret.numContinuousW1Sending += listTask[3].result.numContinuousW1Sending
		ret.numContinuousD1Buying += listTask[3].result.numContinuousD1Buying
		ret.numContinuousD3Buying += listTask[3].result.numContinuousD3Buying
		ret.numContinuousW1Buying += listTask[3].result.numContinuousW1Buying
		ret.amountRecentD3Sending += listTask[3].result.amountRecentD3Sending
		ret.amountWakeupW1Sending += listTask[3].result.amountWakeupW1Sending
		ret.amountWakeupM1Sending += listTask[3].result.amountWakeupM1Sending
		ret.amountRecentD3Buying += listTask[3].result.amountRecentD3Buying
		ret.amountWakeupW1Buying += listTask[3].result.amountWakeupW1Buying
		ret.amountWakeupM1Buying += listTask[3].result.amountWakeupM1Buying
		ret.amountContinuousD1Sending += listTask[3].result.amountContinuousD1Sending
		ret.amountContinuousD3Sending += listTask[3].result.amountContinuousD3Sending
		ret.amountContinuousW1Sending += listTask[3].result.amountContinuousW1Sending
		ret.amountContinuousD1Buying += listTask[3].result.amountContinuousD1Buying
		ret.amountContinuousD3Buying += listTask[3].result.amountContinuousD3Buying
		ret.amountContinuousW1Buying += listTask[3].result.amountContinuousW1Buying
		ret.balanceSupplierMean += listTask[4].result.balanceSupplierMean
		ret.balanceSupplierStd += listTask[4].result.balanceSupplierStd
		ret.balanceSupplierPercent20 += listTask[4].result.balanceSupplierPercent20
		ret.balanceSupplierPercent40 += listTask[4].result.balanceSupplierPercent40
		ret.balanceSupplierMiddle += listTask[4].result.balanceSupplierMiddle
		ret.balanceSupplierPercent60 += listTask[4].result.balanceSupplierPercent60
		ret.balanceSupplierPercent80 += listTask[4].result.balanceSupplierPercent80
		ret.balanceSupplierPercent95 += listTask[4].result.balanceSupplierPercent95
		ret.amountSupplierBalanceBelow20 += listTask[4].result.amountSupplierBalanceBelow20
		ret.amountSupplierBalanceBelow40 += listTask[4].result.amountSupplierBalanceBelow40
		ret.amountSupplierBalanceBelow60 += listTask[4].result.amountSupplierBalanceBelow60
		ret.amountSupplierBalanceBelow80 += listTask[4].result.amountSupplierBalanceBelow80
		ret.amountSupplierBalanceAbove95 += listTask[4].result.amountSupplierBalanceAbove95
		ret.numRealizedProfit += listTask[5].result.numRealizedProfit
		ret.numRealizedLoss += listTask[5].result.numRealizedLoss
		ret.amountRealizedProfitBillion += listTask[5].result.amountRealizedProfitBillion
		ret.amountRealizedLossBillion += listTask[5].result.amountRealizedLossBillion
		return ret
		end
