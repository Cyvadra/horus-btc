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

# DateTime alignment
	originalfromDate = DateTime(2018,1, 1, 0, 0, 0)
	originaltoDate   = DateTime(2021,5,31,23,00,00)
	fromDate = originalfromDate + Hour(3*includePrev)
	toDate   = originaltoDate - Hour(3*includePrev)
	tsFromDate   = dt2unix(fromDate)
	tsToDate     = dt2unix(toDate)
	y_base_index = findfirst(x->x>tsFromDate, df.timestamp)-1
	x_base_index = findfirst(x->x.timestamp>tsFromDate, resultsCalculated)-1
	@assert df[y_base_index, :timestamp] == resultsCalculated[x_base_index].timestamp == tsFromDate
	x_last_index = findlast(x->0<x.timestamp<=tsToDate, resultsCalculated)
	y_last_index = findlast(x->0<x<=resultsCalculated[x_last_index].timestamp, df.timestamp)
	@assert df[y_last_index, :timestamp] == resultsCalculated[x_last_index].timestamp <= tsToDate
	@assert y_last_index - y_base_index == x_last_index - x_base_index

	X = GenerateXAtIndexI.(collect(x_base_index:x_last_index))
	Y = GenerateYAtRowI.(collect(y_base_index:y_last_index))

yLength       = 16
inputSize     = length(X[1])
modelWidth    = 256
data          = zip(X,Y)
nEpoch        = 30
nThrottle     = 10

m = Chain(
		Dense(inputSize, modelWidth),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, yLength),
	)
ps = params(m);


opt        = ADAM()
tx, ty     = (X[5], Y[5])
evalcb     = () -> @show loss(tx, ty)
loss(x, y) = Flux.Losses.mae(m(x), y)
@show loss(tx, ty)
Flux.train!(loss, ps, data, opt)
@show loss(tx, ty)


for epoch = 1:nEpoch
	@info "Epoch $(epoch) / $nEpoch"
	Flux.train!(loss, ps, data, opt, cb = Flux.throttle(evalcb, nThrottle))
	end





















