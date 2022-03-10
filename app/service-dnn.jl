using Flux
using DataFrames
using FinanceDB
using Dates
using JLD2
include("./struct-ResultCalculations.jl")
resultsCalculated = ResultCalculations[]
resultsCalculated = JLD2.load("/mnt/data/tmp/results.2020.08.jld2", "results")

# Definition of Y
#=
	OHLC of $stepsNext tick
=#
	struct GonnaHappen
		ChangedPercents::Float32
		HighestPercents::Float32
		LowestPercents::Float32
		NextOpenPercents::Float32
		end
	function flat(v::Vector{GonnaHappen})::Vector{Float32}
		ret = Float32[]
		for gh in v
			push!(ret,
					gh.ChangedPercents,
					gh.HighestPercents,
					gh.LowestPercents,
					gh.NextOpenPercents,
				)
		end
		return ret
		end
	function restruct(v::Vector{Float32})::Vector{GonnaHappen}
		if !iszero( length(v) % 4 )
			throw("array length incorrect!")
		end
		ret = GonnaHappen[]
		for i in 1:4:length(v)
			push!(ret, GonnaHappen(v[i], v[i+1], v[i+2], v[i+3]))
		end
		return ret
		end
	function GenerateYAtRowIAfterStepsN(i::Int, n::Int)::GonnaHappen
		currentPrice = df[i,:mid]
		return GonnaHappen(
			df[i+n, :mid] / currentPrice - 1.0,
			max(df[i:i+n, :high]...) / currentPrice - 1.0,
			min(df[i:i+n, :low]...) / currentPrice - 1.0,
			df[i+n, :open] / currentPrice - 1.0,
			)
		end
	function GenerateYAtRowI(i::Int)::Vector{Float32}
		return flat(GenerateYAtRowIAfterStepsN.(i, stepsNext))
		end



# Definition of X
#=
	Previous $includePrev data, auto-configure weight
=#
	function GenerateXAtIndexI(i::Int)::Vector{Float32}
		# return results2vector(resultsCalculated[i-includePrev+1:i])
		return result2vector(resultsCalculated[i])
		end


# Timezone
	function dt2unix(dt::DateTime)::Int32
		return round(Int32, datetime2unix(dt - Hour(8)))
		end
	function unix2dt(ts::Int32)::DateTime
		return unix2datetime(ts) + Hour(8)
		end

modelWidth    = 512
nEpoch        = 30
nThrottle     = 10

m = Chain(
		Dense(inputSize, modelWidth),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, modelWidth, tanh_fast),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, yLength),
	)
ps = params(m);










