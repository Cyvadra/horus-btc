using Flux
using DataFrames
using FinanceDB
using Dates
using JLD2
include("./struct-ResultCalculations.jl")
resultsCalculated = ResultCalculations[]
resultsCalculated = JLD2.load("/mnt/data/tmp/results.2020.08.jld2", "results")
for i in 1:length(resultsCalculated)
	# 2020.08 was set to tsStart, correct to tsEnd
	resultsCalculated[i].timestamp += 10800
	end

includePrev = 6

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
		res = GetBTCPriceWhen(ts:ts+3600) ./ bp .- 1.0
		return [
			# sim 10m
			sort(res[300:900])[300],
			# 15m
			res[900],
			# sim 20m
			sort(res[900:1800])[450],
			# 30m
			res[1800],
			# sim 45m
			sort(res[1800:3600])[900],
		]
		end
	function GenerateHistAtRowI(i::Int)::Vector{Float32}
		return [df[i, :ma5], df[i, :ma10]]
		end



# Definition of X
#=
	Previous $includePrev data, auto-configure weight
=#
	function GenerateXAtIndexI(i::Int)::Vector{Float32}
		return vcat(result2vector_expand.(
			resultsCalculated[i - includePrev + 1 : i]
			)...)
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
	oriY = GenerateYAtRowI.(collect(y_base_index:y_last_index))
	tmpHist = GenerateHistAtRowI.(collect(y_base_index:y_last_index))
	for i in 1:length(oriX)
		append!(oriX[i], tmpHist[i])
		end

	tmpList = sum.(oriY)
	sortedTmpList = sort(tmpList)[21:end-20]
	tmpVal  = mean(sortedTmpList)
	while abs(tmpVal) > 1.0
		if tmpVal < 0
			if rand() < 0.8
				popfirst!(sortedTmpList)
			else
				pop!(sortedTmpList)
			end
		elseif tmpVal > 0
			if rand() < 0.8
				pop!(sortedTmpList)
			else
				popfirst!(sortedTmpList)
			end
		end
		tmpVal = mean(sortedTmpList)
	end

	tmpInds = map(x->sortedTmpList[1] <= sum(x) <= sortedTmpList[end], oriY)
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

nEpoch    = 800
nThrottle = 10

m = Chain(
		Dense(inputSize, 256),
		Dense(256, 128),
		Dense(128, 128),
		Dense(128, 64),
		Dense(64, yLength),
	)	
ps = params(m);


opt        = ADADelta(0.9, 3e-11)
tx, ty     = (test_x[5], test_y[5])
evalcb     = () -> @show loss(tx, ty)
loss(x, y) = Flux.Losses.mse(m(x), y)
@show loss(tx, ty)
Flux.train!(loss, ps, data, opt)
@show loss(tx, ty)

prev_loss = [ Flux.Losses.mse(m(training_x[i]), training_y[i]) for i in 1:length(training_x) ] |> mean
ps_saved  = deepcopy(collect(ps))
for epoch = 1:nEpoch
	@info "Epoch $(epoch) / $nEpoch"
	Flux.train!(loss, ps, data, opt, cb = Flux.throttle(evalcb, nThrottle))
	this_loss = [ Flux.Losses.mse(m(training_x[i]), training_y[i]) for i in 1:length(training_x) ] |> mean
	if this_loss < 0.8*prev_loss
		ps_saved  = deepcopy(collect(ps))
		prev_loss = this_loss
	end
	end


