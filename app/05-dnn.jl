using Flux
using DataFrames
using FinanceDB
using Dates
include("./05-00-loadresults.jl")
resultsCalculated = ResultCalculations[]

# Params
	includePrev = 12 # ticks, [current-x+1:current]
	stepsNext   = Int[1,2,4,8] # predict next n status


# Load market data
	FinanceDB.SetDataFolder("/mnt/data/mmap")
	d = FinanceDB.GetDerivativeWindowed("BTC_USDT")["H3"];
	df = DataFrame(
		timestamp = d.Timestamps[],
		open = d.Open[],
		high = d.High[],
		low  = d.Low[],
		close = d.Close[],
		vol   = d.Volume[]
		);
	df = df[1:findfirst(x->iszero(x), d.Timestamps[])-1, :];
	df[!,:mid] = (2df.open + df.close + 3df.high + 3df.low) ./ 9;
	GC.gc()

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
		return results2vector(resultsCalculated[i-includePrev+1:i])
		end


# Timezone
	function dt2unix(dt::DateTime)::Int32
		return round(Int32, datetime2unix(dt - Hour(8)))
		end
	function unix2dt(ts::Int32)::DateTime
		return unix2datetime(ts) + Hour(8)
		end

# DateTime alignment
	originalfromDate = DateTime(2018,1, 1, 0, 0, 0)
	originaltoDate   = DateTime(2021,5,31,23,59,59)
	fromDate = originalfromDate + Hour(3*includePrev)
	toDate   = originaltoDate - Hour(3*includePrev)
	tsFromDate   = dt2unix(fromDate)
	tsToDate     = dt2unix(toDate)
	y_base_index = findfirst(x->x>tsFromDate, df.timestamp)-1
	x_base_index = findfirst(x->x.timestamp>tsFromDate, resultsCalculated)-1
	@assert df[y_base_index, :timestamp] == resultsCalculated[x_base_index].timestamp == tsFromDate
	y_last_index = findlast(x->x<=tsToDate, df.timestamp)
	x_last_index = findlast(x->x.timestamp<=tsToDate, resultsCalculated)
	@assert df[y_last_index, :timestamp] == resultsCalculated[x_last_index].timestamp == tsToDate
	@assert y_last_index - y_base_index == x_last_index - x_base_index



modelWidth    = 512
yLength       = 16

model = Chain(
		Parallel(vcat, Dense(inputSize, inputSize), log2),
		Dense(2inputSize, 2inputSize),
		Dense(2inputSize, modelWidth),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, yLength),
	)

























