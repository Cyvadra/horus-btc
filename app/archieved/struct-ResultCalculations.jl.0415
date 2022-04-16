
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
	_types = Vector{DataType}(collect(ResultCalculations.types))
	_syms  = collect(fieldnames(ResultCalculations))
	_names = string.(_syms)
	_len   = length(_types)

#= Data Pretreatment
		fieldname starts with:
			timestamp
				ignore
			num
				use directly
			amount
				log2()
			percent
				use directly
=#

	need_log2 = findall(x->x[1:3]=="amo" || x[1:3]=="num", _names)
	function result2vector_expand(res::ResultCalculations)::Vector{Float32}
		ret = Float32[]
		for i in 2:_len
			tmpVal = getfield(res,i)
			push!(ret, tmpVal)
			if i in need_log2
				if tmpVal < 0
					push!( ret, -log2(abs(tmpVal)+1) )
				else
					push!( ret, log2(tmpVal+1) )
				end
			end
		end
		return ret
		end
	function result2vector(res::ResultCalculations)::Vector{Float32}
		ret = Vector{Float32}(undef, _len-1)
		for i in 2:_len
			if i in need_log2
				tmpVal = getfield(res,i)
				if tmpVal < 0
					ret[i-1] = -log2(abs(tmpVal)+1)
				else
					ret[i-1] = log2(tmpVal+1)
				end
			else
				ret[i-1] = getfield(res,i)
			end
		end
		return ret
		end
	function results2vector(v::Vector{ResultCalculations})::Vector{Float32}
		lenUnits = _len - 1
		ret = Vector{Float32}(undef, length(v)*lenUnits)
		for i in 1:length(v)
			for j in 2:_len
				if j in need_log2
					tmpVal = getfield(v[i],j)
					if tmpVal < 0
						ret[(i-1)*lenUnits + j-1] = -log2(abs(tmpVal)+1)
					else
						ret[(i-1)*lenUnits + j-1] = log2(tmpVal+1)
					end
				else
					ret[(i-1)*lenUnits + j-1] = getfield(v[i],j)
				end
			end
		end
		return ret
		end
	function flat(res::ResultCalculations)::Vector{Float32}
		ret = Vector{Float32}(undef, _len-1)
		[ ret[i-1] = getfield(res,i) for i in 2:_len ];
		return ret
		end



using Statistics

import Statistics:mean
function mean(v::Vector{ResultCalculations})::ResultCalculations
	ret = ResultCalculations(zeros(_len)...)
	for i in 1:length(_syms)
		s = _syms[i]
		tmpVal = mean(getfield.(v, s))
		if typeof(tmpVal) !== _types[i]
			tmpVal = round(_types[i], tmpVal)
		end
		setfield!(ret, s, tmpVal)
	end
	# modify ts yourself
	return ret
	end


