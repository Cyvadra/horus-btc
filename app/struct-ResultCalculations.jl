
	# mutable struct ResultCalculations
	ResultCalculations
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
		tmpVal = Statistics.mean(getfield.(v, s))
		if typeof(tmpVal) !== _types[i]
			tmpVal = round(_types[i], tmpVal)
		end
		setfield!(ret, s, tmpVal)
	end
	# modify ts yourself
	return ret
	end


