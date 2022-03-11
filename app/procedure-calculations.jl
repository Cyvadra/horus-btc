
	AddressService
	GetBTCPriceWhen

	sumAddrId
	sumTagNew
	sumAmount
	sumTs

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
		concreteBalances = abs.(AddressService.GetFieldBalance(
			cacheAddrId[][ concreteIndexes ]))
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
