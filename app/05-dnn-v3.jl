using Flux
using DataFrames
using FinanceDB
using Dates
using JLD2
include("./utils.jl")
include("./service-FinanceDB.jl")
include("./service-Results-H3.jl")

# Config
	includePrev = 6
	numPrevResultsMA = 24 # 72 hours

# Load data
	tmpN = TableResults.Findfirst(x->iszero(x), :timestamp) - 1
	resultsCalculated = TableResults.GetRow(collect(1:tmpN))

# Pretreatment of input
	resultMean    = mean(resultsCalculated);
	resultsMA     = deepcopy(resultsCalculated);
	tmpLen        = length(resultsCalculated);
	# Generate MA
	for i in 2:numPrevResultsMA
		resultsMA[i] = mean(resultsCalculated[1:i-1])
		end
	for i in numPrevResultsMA+1:tmpLen
		resultsMA[i] = mean(resultsCalculated[i-numPrevResultsMA:i-1])
		end
	[ resultsMA[i].timestamp = resultsCalculated[i].timestamp for i in 1:tmpLen ];
	# Generate Bias
	tmpSyms  = fieldnames(ResultCalculations) |> collect
	tmpTypes = ResultCalculations.types |> collect
	resultsBias = Vector{Float32}[]
	for i in 1:tmpLen
		tmpRet  = Float32[]
		tmpDiff = resultsCalculated[i] - resultsMA[i]
		for j in 2:length(tmpTypes)
			tmpVal = getfield(tmpDiff, tmpSyms[j]) / getfield(resultMean, tmpSyms[j])
			if isnan(tmpVal) || isinf(tmpVal)
				tmpVal = 0.0
			end
			push!(tmpRet, tmpVal)
		end
		push!(resultsBias, safe_log2.(tmpRet))
	end

# Definition of X
	function GenerateXAtIndexI(i::Int)::Vector{Float32}
	#	Previous $includePrev data, auto-configure weight
		tmpRange = i - includePrev + 1 : i
		ret = vcat( resultsBias[tmpRange]... )
		tmpTs = resultsCalculated[i].timestamp |> ts2ind
		append!(ret,
			[
				(tmpTs |> TableTick.GetFieldClose) / 
				(tmpTs |> TableTick.GetFieldMA10)
				for j in tmpRange
			]
		)
		append!(ret,
			[
				(tmpTs |> TableTick.GetFieldHigh) / 
				(tmpTs |> TableTick.GetFieldMA10)
				for j in tmpRange
			]
		)
		append!(ret,
			[
				(tmpTs |> TableTick.GetFieldLow) / 
				(tmpTs |> TableTick.GetFieldMA10)
				for j in tmpRange
			]
		)
		return ret
		end

# Validation of X
	function CheckX()::Nothing
		numGaps = round(Int, 
			(resultsCalculated[end].timestamp - resultsCalculated[1].timestamp) / 
			(resultsCalculated[3].timestamp - resultsCalculated[2].timestamp)
			)
		@assert numGaps+1 == length(resultsCalculated)
		return nothing
		end
	CheckX()
