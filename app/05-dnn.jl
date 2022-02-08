using Flux
using DataFrames

inputSize     = nrow(df)-1 # ignore timestamp

stepPrev  = 10 # ticks
stepNext  = 1  # predict which

tsFirst   = max(df[1,:timestamp], d.TsFirst)
tsEnd     = min(df[end,:timestamp], d.TsEnd)
numTicks  = floor(Int, (tsEnd-tsFirst)/d.TsInterval)

dfStartRow = findfirst(x->x>=tsFirst, df.timestamp)
dfEndRow   = findlast(x->x!==0 && x<=tsEnd, df.timestamp)
deStartRow = findfirst(x->x>=tsFirst, d.Timestamps[])
deEndRow   = findlast(x->x!==0 && x<=tsEnd, d.Timestamps[])


# Definition of X
#=
	Previous $stepPrev data, auto-configure weight
=#



# Definition of Y
#=
	OHLC of $stepNext tick
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

























