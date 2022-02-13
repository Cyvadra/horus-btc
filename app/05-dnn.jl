using Flux
using DataFrames
using FinanceDB


# Params
	includePrev = 10 # ticks
	stepsNext   = Int[1,2,4,8,16] # predict next n status

# Feature definition
	struct GonnaHappen
		ChangedPercents::Float32
		HighestPercents::Float32
		LowestPercents::Float32
		NextOpenPercents::Float32
		end

# Load market data
	FinanceDB.SetDataFolder("/mnt/data/mmap")
	d = FinanceDB.GetDerivative("BTC_USDT");
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
	function GenerateYAtRowIAfterStepsN(i::Int, n::Int)::GonnaHappen
		currentPrice = df[i,:mid]
		return GonnaHappen(
			df[i+n, :mid] / currentPrice - 1.0,
			max(df[i:i+n, :high]...) / currentPrice - 1.0,
			min(df[i:i+n, :low]...) / currentPrice - 1.0,
			df[i+n, :open] / currentPrice - 1.0,
			)
		end


# Definition of X
#=
	Previous $includePrev data, auto-configure weight
=#



modelWidth    = 512
yLength       = 16

model = Chain(
		Parallel(vcat, Dense(inputSize, inputSize), log2),
		Dense(2inputSize, 2inputSize),
		Dense(2inputSize, modelWidth),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, yLength),
	)

























