
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
		numWakeupD1Sending::Int32
		numWakeupD3Sending::Int32
		numRecentD3Buying::Int32
		numWakeupD1Buying::Int32
		numWakeupD3Buying::Int32
		numContinuousD1Sending::Int32
		numContinuousD3Sending::Int32
		numContinuousW1Sending::Int32
		numContinuousD1Buying::Int32
		numContinuousD3Buying::Int32
		numContinuousW1Buying::Int32
		amountRecentD3Sending::Float32
		amountWakeupD1Sending::Float32
		amountWakeupD3Sending::Float32
		amountRecentD3Buying::Float32
		amountWakeupD1Buying::Float32
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
			wakeupD1Sending = map(t->tsMid-t > seconds.Day, concreteLastPayed),
			wakeupD3Sending = map(t->tsMid-t > 3seconds.Day, concreteLastPayed),

			recentD3Buying = map(t->tsMid-t < 3seconds.Day, concreteLastReceived),
			wakeupD1Buying = map(t->tsMid-t > seconds.Day, concreteLastReceived),
			wakeupD3Buying = map(t->tsMid-t > 3seconds.Day, concreteLastReceived),

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
				safe_sum(tmpIndexes.wakeupD1Sending),
				safe_sum(tmpIndexes.wakeupD3Sending),
				safe_sum(tmpIndexes.recentD3Buying),
				safe_sum(tmpIndexes.wakeupD1Buying),
				safe_sum(tmpIndexes.wakeupD3Buying),
				safe_sum(tmpIndexes.contiD1Sending),
				safe_sum(tmpIndexes.contiD3Sending),
				safe_sum(tmpIndexes.contiW1Sending),
				safe_sum(tmpIndexes.contiD1Buying),
				safe_sum(tmpIndexes.contiD3Buying),
				safe_sum(tmpIndexes.contiW1Buying),
				
				reduce(+,concreteAmounts[tmpIndexes.recentD3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupD1Sending]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupD3Sending]),
				reduce(+,concreteAmounts[tmpIndexes.recentD3Buying]),
				reduce(+,concreteAmounts[tmpIndexes.wakeupD1Buying]),
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
			)
		return ret
		end
	function CalcAddressBuyer(cacheAddrId::Base.RefValue, cacheTagNew::Base.RefValue, cacheAmount::Base.RefValue, cacheTs::Base.RefValue)::CellAddressBuyer
		buyerIndexes  = map(x->!x, cacheTagNew[])
		buyerIndexes  = buyerIndexes .&& cacheAmount[] .> 0.0
		buyerBalances = abs.(AddressService.GetFieldBalance(
			cacheAddrId[][ buyerIndexes ]))
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
		CellAddressBuyer, CalcAddressBuyer))
	push!(Calculations, CalcCell(
		CellAddressUsdtDiff, CalcAddressUsdtDiff))

	isdir("/tmp/julia-cache/") ? nothing : mkdir("/tmp/julia-cache/")

	function GenerateAndLoadResultCalculations()::String
		s = "mutable struct ResultCalculations\n"
		for c in Calculations
			tmpTypes = collect(c.resultType.types)
			tmpNames = string.(fieldnames(c.resultType))
			for i in 1:length(tmpTypes)
				s *= "\t$(tmpNames[i])::$(tmpTypes[i])\n"
			end
		end
		s *= "end"
		tmpFileName = "/tmp/julia-cache/" * join(rand('a':'z',6)) * ".jl"
		write(tmpFileName, s)
		include(tmpFileName)
		rm(tmpFileName)
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
		ret.$(tmpNames[j]) += listTask[$tmpCounter].result.$(tmpNames[j])"
				tmpCounter += 1
			end
		end
		s *= "
		return ret
		end"
		tmpFileName = "/tmp/julia-cache/" * join(rand('a':'z',6)) * ".jl"
		write(tmpFileName, s)
		include(tmpFileName)
		rm(tmpFileName)
		return s
		end

	GenerateAndLoadResultCalculations();
	GenerateAndLoadDoCalculations();

