
	AddressService
	GetBTCPriceWhen
	# ResultCalculations
	using Statistics

	seconds = (
		Hour  = 3600,
		Day   = 3600 * 24,
		Week  = 3600 * 24 * 7,
		Month = 3600 * 24 * 30,
		)

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
		amountReceivedPercent25::Float32
		amountReceivedPercent50::Float32
		amountReceivedPercent75::Float32
		amountReceivedMean::Float32
		amountSentPercent25::Float32
		amountSentPercent50::Float32
		amountSentPercent75::Float32
		amountSentMean::Float32
		end
	mutable struct CellAddressAccumulation
		numRecentH3Sending::Int32
		numRecentD3Sending::Int32
		numWakeupD3Sending::Int32
		numRecentH3Buying::Int32
		numRecentD3Buying::Int32
		numWakeupD3Buying::Int32
		numContinuousD1Sending::Int32
		numContinuousD3Sending::Int32
		numContinuousW1Sending::Int32
		numContinuousD1Buying::Int32
		numContinuousD3Buying::Int32
		numContinuousW1Buying::Int32
		amountRecentH3Sending::Float32
		amountRecentD3Sending::Float32
		amountWakeupD3Sending::Float32
		amountRecentH3Buying::Float32
		amountRecentD3Buying::Float32
		amountWakeupD3Buying::Float32
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
		averageRateWinningSupplier::Float32
		averageRateWinningSupplierWeighted::Float32
		averageUsdtNetRealizedSupplier::Float32
		averageUsdtNetUnrealizedSupplier::Float32
		averageUsdtAmountWonSupplier::Float32
		averageUsdtAmountLostSupplier::Float32
		averageMintTimestampSupplier::Float32
		averageMintTimestampSupplierWeighted::Float32
		averageSpentTimestampSupplier::Float32
		averageSpentTimestampSupplierWeighted::Float32
		end
	mutable struct CellAddressBuyer
		balanceBuyerMean::Float32
		balanceBuyerStd::Float32
		balanceBuyerPercent20::Float32
		balanceBuyerPercent40::Float32
		balanceBuyerMiddle::Float32
		balanceBuyerPercent60::Float32
		balanceBuyerPercent80::Float32
		balanceBuyerPercent95::Float32
		amountBuyerBalanceBelow20::Float32
		amountBuyerBalanceBelow40::Float32
		amountBuyerBalanceBelow60::Float32
		amountBuyerBalanceBelow80::Float32
		amountBuyerBalanceAbove80::Float32
		amountBuyerBalanceAbove95::Float32
		averageRateWinningBuyer::Float32
		averageRateWinningBuyerWeighted::Float32
		averageUsdtNetRealizedBuyer::Float32
		averageUsdtNetUnrealizedBuyer::Float32
		averageUsdtAmountWonBuyer::Float32
		averageUsdtAmountLostBuyer::Float32
		averageMintTimestampBuyer::Float32
		averageMintTimestampBuyerWeighted::Float32
		averageSpentTimestampBuyer::Float32
		averageSpentTimestampBuyerWeighted::Float32
		end
	mutable struct CellAddressUsdtDiff
		numRealizedProfit::Int32
		numRealizedLoss::Int32
		amountRealizedProfitMillion::Float64
		amountRealizedLossMillion::Float64
		numWinning::Int32
		numLossing::Int32
		amountUsdtWonMillion::Float64
		amountUsdtLostMillion::Float64
		end
	mutable struct CellAddressMomentum
		# all in days
		numSupplierMomentum::Float32
		numSupplierMomentumMean::Float32
		numBuyerMomentum::Float32
		numBuyerMomentumMean::Float32
		numRegularBuyerMomentum::Float32
		numRegularBuyerMomentumMean::Float32
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
				safe_sum(cacheTagNew[]) / length(cacheAddrId[]),
				numOutput / _len,
				numInput / _len,
			)
		return ret
		end
	function CalcAddressDirection(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressDirection
		concreteIndexes  = map(x->!x, cacheTagNew[])
		concreteBalances = AddressService.GetFieldBalance(cacheAddrId[][ concreteIndexes ])
		concretePercents = cacheAmount[][ concreteIndexes ] ./ concreteBalances
		sortedAmountReceived = filter(x->x>0, cacheAmount[][ concreteIndexes ]) |> sort
		sortedAmountSent     = abs.(filter(x->x<0, cacheAmount[][ concreteIndexes ])) |> sort
		concreteAmounts  = abs.( cacheAmount[][ concreteIndexes ] )
		tmpIndexes = (
			cpb10 = map(x-> 0.00 < x <= 0.10, concretePercents),
			cpb25 = map(x-> 0.00 < x <= 0.25, concretePercents),
			cpb50 = map(x-> 0.00 < x <= 0.50, concretePercents),
			cpb80 = map(x-> 0.00 < x <= 0.80, concretePercents),
			cpb95 = map(x-> 0.00 < x <= 0.95, concretePercents),
			wpb10 = map(x-> -0.10 <= x < 0.0, concretePercents),
			wpb25 = map(x-> -0.25 <= x < 0.0, concretePercents),
			wpb50 = map(x-> -0.50 <= x < 0.0, concretePercents),
			wpa80 = map(x-> x <= -0.80, concretePercents),
			wpa95 = map(x-> x <= -0.95, concretePercents),
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

				getPercent(sortedAmountReceived, 0.25),
				getPercent(sortedAmountReceived, 0.5),
				getPercent(sortedAmountReceived, 0.75),
				safe_mean(sortedAmountReceived),
				getPercent(sortedAmountSent, 0.25),
				getPercent(sortedAmountSent, 0.5),
				getPercent(sortedAmountSent, 0.75),
				safe_mean(sortedAmountSent),
			)
		return ret
		end
	function CalcAddressAccumulation(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressAccumulation
		tsMin = min( cacheTs[][1], cacheTs[][end] )
		tsMax = max( cacheTs[][1], cacheTs[][end] )
		tsMid = round(Int32, (0.0+tsMin+tsMax)/2)
		concreteIndexes  = map(x->!x, cacheTagNew[])
		ids = cacheAddrId[][concreteIndexes]
		concreteLastPayed    = AddressService.GetFieldTimestampLastPayed(ids)
		concreteLastReceived = AddressService.GetFieldTimestampLastReceived(ids)
		concreteAmounts      = cacheAmount[][concreteIndexes]
		concreteAmountsSend  = concreteAmounts .< 0.0
		concreteAmountsBuy   = concreteAmounts .> 0.0
		tmpIndexes = (
			recentH3Sending = map(t->!iszero(t) && tsMid-t < 3seconds.Hour, concreteLastPayed),
			recentD3Sending = map(t->!iszero(t) && 3seconds.Hour < tsMid-t < 3seconds.Day, concreteLastPayed),
			wakeupD3Sending = map(t->!iszero(t) && tsMid-t > 3seconds.Day, concreteLastPayed),

			recentH3Buying = map(t->!iszero(t) && tsMid-t < 3seconds.Hour, concreteLastReceived),
			recentD3Buying = map(t->!iszero(t) && 3seconds.Hour < tsMid-t < 3seconds.Day, concreteLastReceived),
			wakeupD3Buying = map(t->tsMid-t > 3seconds.Day, concreteLastReceived),

			contiD1Sending = map(t->!iszero(t) && tsMax-t > seconds.Day, concreteLastReceived) .&& concreteAmountsSend,
			contiD3Sending = map(t->!iszero(t) && tsMax-t > 3seconds.Day, concreteLastReceived) .&& concreteAmountsSend,
			contiW1Sending = map(t->!iszero(t) && tsMax-t > 7seconds.Day, concreteLastReceived) .&& concreteAmountsSend,

			contiD1Buying  = map(t->!iszero(t) && tsMax-t >= seconds.Day, concreteLastPayed) .&& concreteAmountsBuy,
			contiD3Buying  = map(t->!iszero(t) && tsMax-t > 3seconds.Day, concreteLastPayed) .&& concreteAmountsBuy,
			contiW1Buying  = map(t->!iszero(t) && tsMax-t > 7seconds.Day, concreteLastPayed) .&& concreteAmountsBuy,
			)
		concreteAmounts = abs.(concreteAmounts)
		ret = CellAddressAccumulation(
				safe_sum(tmpIndexes.recentH3Sending),
				safe_sum(tmpIndexes.recentD3Sending),
				safe_sum(tmpIndexes.wakeupD3Sending),
				safe_sum(tmpIndexes.recentH3Buying),
				safe_sum(tmpIndexes.recentD3Buying),
				safe_sum(tmpIndexes.wakeupD3Buying),
				safe_sum(tmpIndexes.contiD1Sending),
				safe_sum(tmpIndexes.contiD3Sending),
				safe_sum(tmpIndexes.contiW1Sending),
				safe_sum(tmpIndexes.contiD1Buying),
				safe_sum(tmpIndexes.contiD3Buying),
				safe_sum(tmpIndexes.contiW1Buying),
				
				reduce(+,concreteAmounts[tmpIndexes.recentH3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.recentD3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupD3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.recentH3Buying]),
				reduce(+,concreteAmounts[tmpIndexes.recentD3Buying]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupD3Buying]),
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
		weightSupplier   = safe_weight(concreteBalances)
		concreteAmounts  = abs.(cacheAmount[][ concreteIndexes ])
		if length(concreteBalances) < 10
			if isempty(concreteBalances)
				append!(concreteBalances, zeros(10))
				append!(concreteAmounts, zeros(10))
			else
				for j in 1:5
					pushfirst!(concreteBalances, rand(concreteBalances))
					pushfirst!(concreteAmounts, rand(concreteAmounts))
					push!(concreteBalances, rand(concreteBalances))
					push!(concreteAmounts, rand(concreteAmounts))
				end
			end
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
				AddressService.GetFieldRateWinning(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldRateWinning(cacheAddrId[][concreteIndexes]) .* weightSupplier |> safe_sum,
				AddressService.GetFieldUsdtNetRealized(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldUsdtNetUnrealized(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldUsdtAmountWon(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldUsdtAmountLost(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldAverageMintTimestamp(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldAverageMintTimestamp(cacheAddrId[][concreteIndexes]) .* weightSupplier |> safe_sum,
				AddressService.GetFieldAverageSpentTimestamp(cacheAddrId[][concreteIndexes]) |> safe_mean,
				AddressService.GetFieldAverageSpentTimestamp(cacheAddrId[][concreteIndexes]) .* weightSupplier |> safe_sum,
			)
		return ret
		end
	function CalcAddressBuyer(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressBuyer
		buyerIndexes  = map(x->!x, cacheTagNew[])
		buyerIndexes  = buyerIndexes .&& cacheAmount[] .> 0.0
		buyerBalances = abs.(AddressService.GetFieldBalance(
			cacheAddrId[][ buyerIndexes ]))
		weightBuyer   = safe_weight(buyerBalances)
		buyerAmounts  = cacheAmount[][ buyerIndexes ]
		if length(buyerBalances) < 10
			if isempty(buyerBalances)
				append!(buyerBalances, zeros(10))
				append!(buyerAmounts, zeros(10))
			else
				for j in 1:5
					pushfirst!(buyerBalances, rand(buyerBalances))
					pushfirst!(buyerAmounts, rand(buyerAmounts))
					push!(buyerBalances, rand(buyerBalances))
					push!(buyerAmounts, rand(buyerAmounts))
				end
			end
		end
		sortedBalances = sort(buyerBalances)[1:floor(Int, 0.95*end)]
		ret = CellAddressBuyer(
				sum(sortedBalances) / length(sortedBalances),
				Statistics.std(sortedBalances),
				sortedBalances[floor(Int, 0.2*end)],
				sortedBalances[floor(Int, 0.4*end)],
				sortedBalances[floor(Int, 0.5*end)],
				sortedBalances[ceil(Int, 0.6*end)],
				sortedBalances[ceil(Int, 0.8*end)],
				sortedBalances[ceil(Int, 0.95*end)],
				reduce(+, buyerAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.2*end)], buyerBalances)
					]),
				reduce(+, buyerAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.4*end)], buyerBalances)
					]),
				reduce(+, buyerAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.6*end)], buyerBalances)
					]),
				reduce(+, buyerAmounts[
					map(x -> x <= sortedBalances[floor(Int, 0.8*end)], buyerBalances)
					]),
				reduce(+, buyerAmounts[
					map(x -> x >= sortedBalances[floor(Int, 0.8*end)], buyerBalances)
					]),
				reduce(+, buyerAmounts[
					map(x -> x >= sortedBalances[ceil(Int, 0.95*end)], buyerBalances)
					]),
				AddressService.GetFieldRateWinning(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldRateWinning(cacheAddrId[][buyerIndexes]) .* weightBuyer |> safe_sum,
				AddressService.GetFieldUsdtNetRealized(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldUsdtNetUnrealized(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldUsdtAmountWon(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldUsdtAmountLost(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldAverageMintTimestamp(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldAverageMintTimestamp(cacheAddrId[][buyerIndexes]) .* weightBuyer |> safe_sum,
				AddressService.GetFieldAverageSpentTimestamp(cacheAddrId[][buyerIndexes]) |> safe_mean,
				AddressService.GetFieldAverageSpentTimestamp(cacheAddrId[][buyerIndexes]) .* weightBuyer |> safe_sum,
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
			if coinPrice >= boughtPrice
				ret.numRealizedProfit += 1
				ret.amountRealizedProfitMillion += Float64(coinPrice-boughtPrice) * abs(cacheAmount[][i]) / 1e6
			else
				ret.numRealizedLoss += 1
				ret.amountRealizedLossMillion += Float64(boughtPrice-coinPrice) * abs(cacheAmount[][i]) / 1e6
			end
			lastBoughtPrice = AddressService.GetFieldLastPurchasePrice(cacheAddrId[][i])
			if coinPrice >= lastBoughtPrice
				ret.numWinning += 1
				ret.amountUsdtWonMillion += Float64(coinPrice-lastBoughtPrice) * abs(cacheAmount[][i]) / 1e6
			else
				ret.numLossing += 1
				ret.amountUsdtLostMillion += Float64(lastBoughtPrice-coinPrice) * abs(cacheAmount[][i]) / 1e6
			end
		end
		return ret
		end
	function CalcAddressMomentum(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressMomentum
		tmpTs = 0.0 + cacheTs[][end]
		concreteIndexes  = map(x->!x, cacheTagNew[])
		supplierIndexes  = concreteIndexes .&& cacheAmount[] .< 0.0
		buyerIndexes     = cacheAmount[] .> 0.0
		regularIndexes   = concreteIndexes .&& buyerIndexes
		# supplier
		supplierTs0  = AddressService.GetFieldTimestampLastActive(cacheAddrId[][supplierIndexes])
		supplierTs1  = AddressService.GetFieldTimestampLastPayed(cacheAddrId[][supplierIndexes])
		supplierGaps = tmpTs .- [ iszero(supplierTs1[i]) ? supplierTs0[i] : supplierTs1[i] for i in 1:length(supplierTs1) ]
		supplierGaps ./= 86400
		supplierMomentum = 0.0 .- supplierGaps .* cacheAmount[][supplierIndexes]
		# buyer
		buyerTs1  = AddressService.GetFieldTimestampLastReceived(cacheAddrId[][buyerIndexes])
		buyerGaps = tmpTs .- [ iszero(buyerTs1[i]) ? tmpTs : buyerTs1[i] for i in 1:length(buyerTs1) ]
		buyerGaps ./= 86400
		buyerMomentum = buyerGaps .* cacheAmount[][buyerIndexes]
		# regular buyer
		regularTs0  = AddressService.GetFieldTimestampLastActive(cacheAddrId[][regularIndexes])
		regularTs1  = AddressService.GetFieldTimestampLastReceived(cacheAddrId[][regularIndexes])
		regularGaps = tmpTs .- [ iszero(regularTs1[i]) ? regularTs0[i] : regularTs1[i] for i in 1:length(regularTs1) ]
		regularGaps ./= 86400
		regularMomentum = regularGaps .* cacheAmount[][regularIndexes]
		# return
		return CellAddressMomentum(
				safe_sum(supplierMomentum),
				safe_mean(supplierMomentum),
				safe_sum(buyerMomentum),
				safe_mean(supplierMomentum),
				safe_sum(regularMomentum),
				safe_mean(regularMomentum),
			)
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
		CellAddressBuyer, CalcAddressBuyer))
	push!(Calculations, CalcCell(
		CellAddressUsdtDiff, CalcAddressUsdtDiff))
	push!(Calculations, CalcCell(
		CellAddressMomentum, CalcAddressMomentum))

	isdir(folderStructures) ? nothing : mkdir(folderStructures)

	function GenerateAndLoadResultCalculations()::String
		s = "mutable struct ResultCalculations\n"
		s *= "\ttimestamp::Int32\n"
		for c in Calculations
			tmpTypes = collect(c.resultType.types)
			tmpNames = string.(fieldnames(c.resultType))
			for i in 1:length(tmpTypes)
				s *= "\t$(tmpNames[i])::$(tmpTypes[i])\n"
			end
		end
		s *= "end"
		tmpFileName = folderStructures * "ResultCalculations" * ".jl"
		write(tmpFileName, s)
		include(tmpFileName)
		return s
		end

	function GenerateAndLoadDoCalculations()::String
		s = "
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
		wait.(listTask)"
		tmpCounter = 1
		for i in 1:length(Calculations)
			c = Calculations[i]
			tmpTypes = collect(c.resultType.types)
			tmpNames = string.(fieldnames(c.resultType))
			for j in 1:length(tmpTypes)
				s *= "
		@assert !isnan(listTask[$tmpCounter].result.$(tmpNames[j]))
		ret.$(tmpNames[j]) += listTask[$tmpCounter].result.$(tmpNames[j])"
			end
			tmpCounter += 1
		end
		s *= "
		ret.timestamp = cacheTs[end]
		return ret
		end"
		tmpFileName = folderStructures * "DoCalculations" * ".jl"
		write(tmpFileName, s)
		include(tmpFileName)
		return s
		end

	GenerateAndLoadResultCalculations();
	GenerateAndLoadDoCalculations();

