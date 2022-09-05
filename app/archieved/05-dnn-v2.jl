using Flux
using DataFrames
using FinanceDB
using Dates
using JLD2
include("./utils.jl")
include("./struct-ResultCalculations.jl")
resultsCalculated = ResultCalculations[]
resultsCalculated = JLD2.load("/mnt/data/tmp/results.2020.08.jld2", "results")
for i in 1:length(resultsCalculated)
	# 2020.08 was set to tsStart, correct to tsEnd
	resultsCalculated[i].timestamp += 10800
	end

includePrev = 6
numPrevResultsMA = 24 # 72 hours

resultsMA   = deepcopy(resultsCalculated)
resultsStd  = deepcopy(resultsCalculated)
tmpLen      = length(resultsCalculated)
# Generate MA
for i in 2:numPrevResultsMA
	resultsMA[i] = mean(resultsCalculated[1:i-1])
	end
for i in numPrevResultsMA+1:tmpLen
	resultsMA[i] = mean(resultsCalculated[i-numPrevResultsMA:i-1])
	end
[ resultsMA[i].timestamp = resultsCalculated[i].timestamp for i in 1:tmpLen ];

# Definition of X
#	Previous $includePrev data, auto-configure weight
	function CheckX()::Nothing
		numGaps = round(Int, 
			(resultsCalculated[end].timestamp - resultsCalculated[1].timestamp) / 
			(resultsCalculated[3].timestamp - resultsCalculated[2].timestamp)
			)
		@assert numGaps+1 == length(resultsCalculated)
		return nothing
		end
	function GenerateXAtIndexI(i::Int)::Vector{Float32}
		tmpRange = i - includePrev + 1 : i
		ret = [ 
			( flat(resultsCalculated[j]) .+ 1e-9 ) ./ 
			( flat(resultsMA[j]) .+ 1e-9 )
			for j in tmpRange
		]
		ret = vcat(ret...)
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
	CheckX()

# Load market data
	# todo: use middle number instead of mean
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
	df[!, :mid]   = (2df.open + df.close + 3df.high + 3df.low) ./ 9;
	df[!, :ma5]  = deepcopy(df.close)
	for i in 7:nrow(df)
		df[i, :ma5] = sum(df.close[i-5:i-1]) / 5
	end
	df[!, :ma10]  = deepcopy(df.close)
	for i in 11:nrow(df)
		df[i, :ma10] = sum(df.close[i-10:i-1]) / 10
	end
	df.ma5 = df.ma5 ./ df.close .- 1
	df.ma10 = df.ma10 ./ df.close .- 1
	GC.gc()

# Definition of Y : 5m, 10m, 15m, 20m, 30m
	include("./service-FinanceDB.jl")
	function GenerateYAtRowI(i::Int)::Vector{Float32}
		ts  = df[i,:timestamp]
    bp  = GetBTCPriceWhen(ts)
		# sorted = sort(res)
		return [
			min(GetBTCLowWhen(ts:ts+10800)...) / bp,
			max(GetBTCHighWhen(ts:ts+10800)...) / bp,
		]
		end


# Timezone
	function dt2unix(dt::DateTime)::Int32
		return round(Int32, datetime2unix(dt - Hour(8)))
		end
	function unix2dt(ts::Int32)::DateTime
		return unix2datetime(ts) + Hour(8)
		end

# DateTime alignment
	originalfromDate = DateTime(2018,2,1,0,00,00)
	originaltoDate   = DateTime(2020,9,1,0,00,00)
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

	oriX = GenerateXAtIndexI.(collect(x_base_index:x_last_index))
	[ push!(oriX[i], 1.0) for i in 1:length(oriX) ];
	# constant removed since market data has been added into X
	oriY = GenerateYAtRowI.(collect(y_base_index:y_last_index))

	# filter Y
	tmpList = sum.(oriY)
	sortedTmpList = sort(tmpList)[21:end-20]
	tmpVal  = mean(sortedTmpList)
	while abs(tmpVal) > 100.0
		if tmpVal < 0
			popfirst!(sortedTmpList)
			if sortedTmpList[end] > abs(sortedTmpList[1]) && rand() > 0.5
				pop!(sortedTmpList)
			end
		elseif tmpVal > 0
			pop!(sortedTmpList)
			if abs(sortedTmpList[1]) > sortedTmpList[end] && rand() > 0.5
				popfirst!(sortedTmpList)
			end
		end
		tmpVal = mean(sortedTmpList)
	end
	tmpIndsY = map(x->sortedTmpList[1] <= sum(x) <= sortedTmpList[end], oriY)

	# filter X
	tmpList = sum(oriX) ./ length(oriX)
	tmpIndsX = map(x->
		mean( abs.(x .- tmpList) ) < 1.0,
		oriX
		)

	tmpInds = tmpIndsX .&& tmpIndsY
	X = oriX[tmpInds]
	Y = oriY[tmpInds]

	tmpMidN = round(Int, length(X)*0.8)
	tmpIndexes = sortperm(rand(tmpMidN))
	training_x = deepcopy(X[tmpIndexes])
	training_y = deepcopy(Y[tmpIndexes])
	test_x = deepcopy(oriX[tmpMidN+1:end])
	test_y = deepcopy(oriY[tmpMidN+1:end])

yLength   = length(Y[end])
inputSize = length(X[1])
data      = zip(training_x, training_y)

nTolerance = 20
minEpsilon = 1e-15
nThrottle  = 15
modelWidth = 2inputSize

m = Chain(
		Dense(inputSize, modelWidth),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, yLength),
	)
ps = params(m);


opt        = ADAM(2e-8);
tx, ty     = (test_x[5], test_y[5]);
evalcb     = () -> @show loss(tx, ty);
loss(x, y) = Flux.Losses.mse(m(x), y);

# show baseline
tmpLen     = length(training_y[1]);
tmpBase    = [ mean(map(x->x[i], training_y)) for i in 1:tmpLen ];
tmpLoss    = mean([ Flux.Losses.mse(tmpBase, training_y[i]) for i in 1:length(training_y) ]);
@info "Baseline Loss: $tmpLoss"

prev_loss = [ Flux.Losses.mse(m(training_x[i]), training_y[i]) for i in 1:length(training_x) ] |> mean;
ps_saved  = deepcopy(collect(ps));
@info "Initial Loss: $prev_loss"
nCounter  = 0;
tmpFlag   = true;
while true
	Flux.train!(loss, ps, data, opt; cb = Flux.throttle(evalcb, nThrottle))
	this_loss = [ Flux.Losses.mse(m(training_x[i]), training_y[i]) for i in 1:length(training_x) ] |> mean
	if this_loss < 0.95 * prev_loss
		ps_saved  = deepcopy(collect(ps))
		prev_loss = this_loss
		println()
		@info "New best loss $prev_loss"
		nCounter  = 0
		tmpFlag   = true
	else
		@info "loop $nCounter/$nTolerance, loss $this_loss"
		nCounter += 1
		if nCounter > nTolerance
			if tmpFlag == false
				e = opt.epsilon * 1.25
				println()
				@info "Increase epsilon to $e"
				opt.epsilon *= 1.25
				nCounter = 0
			elseif opt.epsilon > minEpsilon
				e = opt.epsilon/2
				println()
				@info "Updated epsilon to $e"
				opt.epsilon /= 2
				nCounter = 0
				nTolerance += 2
				tmpFlag  = false
			else
				@info "Done!"
				break
			end
		end
	end
end


