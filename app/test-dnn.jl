
include("./config.jl");
include("./utils.jl");
include("./service-block_timestamp.jl");
include("./service-FinanceDB.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");
include("./functions-ma.jl");
include("./client-config.jl");

using Dates
using Statistics
using Flux
using ProgressMeter

TableResults.Open(true)
@show GetLastResultsID()

numPrev  = 12 # 36h
postSecs = 10800 # predict 3h
tmpSyms  = ResultCalculations |> fieldnames |> collect
numMiddlefit = 24 # 72h
GlobalVars = (
	ratioSL = 1.05,
	ratioTP = 0.95,
	gpThreshold = Float32(0.27), # map(x->x[1],Y) |> lambda
	gpMinDiff   = Float32(0.35), # map(x->Flux.mae(abs.(x)...),Y) |> lambda
)

function ret2dict(tmpRet::Vector{ResultCalculations})::Dict{String,Vector}
	cacheRet   = Dict{String,Vector}()
	for s in tmpSyms
		if occursin("Billion", string(s))
			cacheRet[string(s)] = map(x->getfield(x,s), tmpRet) .* 1e9
		else
			cacheRet[string(s)] = map(x->getfield(x,s), tmpRet)
		end
	end
	return cacheRet
	end

function GenerateY(ts, postSecs::Int)
	c = middle(GetBTCCloseWhen(ts-900:ts))
	h = reduce(max, GetBTCHighWhen(ts+60:ts+postSecs))
	l = reduce(min, GetBTCLowWhen(ts+60:ts+postSecs))
	h = 100 * (h - c) / c
	l = 100 * (l - c) / c
	return [
		h,
		l,
	]
	end
function GenerateY(anoRet::Dict{String,Vector})
	tsList = anoRet["timestamp"]
	return hcat([ GenerateY(ts, postSecs) for ts in tsList ]...)' |> collect
	end

function GenerateX(anoRet::Dict{String,Vector})::Matrix{Float32}
	sequences = Vector[]
	for k in dnnListTest
		push!(sequences, middlefit(
			safe_log.(Vector{Float32}(anoRet[k])),
			numMiddlefit
		))
	end
	return hcat(sequences...)
	end

function GenerateXY(fromDate::DateTime, toDate::DateTime)
	tmpSecs = Int32(9000) # 2.5h - 3.5h
	X = Vector{Vector{Float32}}()
	Y = Vector{Vector{Float32}}()
	for n in 0:2
		tmpSecs = round(Int32, tmpSecs + 1800n)
		tmpMinuteWeight = round(Int, tmpSecs/360)
		tmpN = round(Int, tmpSecs/tmpMinuteWeight/60-1)
		@showprogress for i in 0:tmpN
			tmpRet  = GenerateWindowedView(
				tmpSecs,
				fromDate + Minute(round(Int, tmpMinuteWeight*i)) |> dt2unix,
				toDate + Minute(round(Int, tmpMinuteWeight*i)) |> dt2unix,
				) |> ret2dict
			tmpX = GenerateX(tmpRet)[numMiddlefit:end, :]
			tmpY = GenerateY(tmpRet)[numMiddlefit:end, :]
			append!(X, [ vcat(tmpX[i-numPrev+1:i,:]...) for i in numPrev+1:size(tmpX)[1] ])
			append!(Y, [ tmpY[i,:] for i in numPrev+1:size(tmpY)[1] ])
			@assert length(X) == length(Y)
		end
	end
	return X, Y
	end
function GenerateTestXY(fromDate::DateTime, toDate::DateTime)
	tmpSecs = Int32(10800)
	X = Vector{Vector{Float32}}()
	Y = Vector{Vector{Float32}}()
	@showprogress for i in 0:5
		tmpRet  = GenerateWindowedView(
			tmpSecs,
			fromDate + Minute(30i) |> dt2unix,
			toDate + Minute(30i) |> dt2unix,
			) |> ret2dict
		tmpX = GenerateX(tmpRet)[numMiddlefit:end, :]
		tmpY = GenerateY(tmpRet)[numMiddlefit:end, :]
		append!(X, [ vcat(tmpX[i-numPrev+1:i,:]...) for i in numPrev+1:size(tmpX)[1] ])
		append!(Y, [ tmpY[i,:] for i in numPrev+1:size(tmpY)[1] ])
		@assert length(X) == length(Y)
	end
	return X, Y
	end
# function GenerateRuntimeX()
# 	toDate   = GetLastResultsTimestamp() |> unix2dt
	# toDate

TRAIN_WITH_GPU = true
# fromDate >= 2018-12-31T23:19:04
fromDate  = DateTime(2019,2,1,0)
toDate    = DateTime(2022,1,31,23,59,59)
fromDateTest = DateTime(2022,3,15,0)
toDateTest   = DateTime(2022,5,20,0)

# Prepare Data
X,Y = GenerateXY(fromDate, toDate);
tmpIndexes = sortperm(rand(length(X)));
training_x = deepcopy(X[tmpIndexes]);
training_y = deepcopy(Y[tmpIndexes]);
throttle_x = deepcopy(X[tmpIndexes[1:2200]]);
throttle_y = deepcopy(Y[tmpIndexes[1:2200]]);
test_x, test_y = GenerateTestXY(fromDateTest, toDateTest);
# tmpVals = sortperm(rand(length(test_x)))[1:500];
# test_x, test_y = test_x[tmpVals], test_y[tmpVals];
if TRAIN_WITH_GPU
	training_x = gpu(training_x)
	training_y = gpu(training_y)
	test_x = gpu(test_x)
	test_y = gpu(test_y)
	throttle_x = gpu(throttle_x)
	throttle_y = gpu(throttle_y)
end

yLength   = length(Y[end])
inputSize = length(X[1])
data      = zip(training_x, training_y);

m = Chain(
			Dense(inputSize, 12, relu),
			Dense(12, 6, softplus),
			Dense(6, yLength),
		);
if TRAIN_WITH_GPU; m = gpu(m); end
ps = Flux.params(m);

opt        = Descent(1e-3);
tx, ty     = (test_x[15], test_y[15]);
loss(x, y) = Flux.mse(m(x),y)
function sub_loss(p, y)
	- ( 0.5 - abs(sigmoid_fast(p-y)-0.5) ) * abs(y)
	end
function loss(x, y)
	p = m(x)
	return sub_loss(p[1], y[1]) + sub_loss(p[2], y[2])
	end
if TRAIN_WITH_GPU
	loss(x, y) = Flux.mae(m(x),y) * (y[1]-y[2]) |> gpu
	loss_direct(p, y) = Flux.mae(p, y) * (y[1]-y[2]) |> gpu
	end
loss_direct(p, y) = Flux.mse(p, y)

tmpLen     = length(test_y[1]);
tmpBase    = [ mean(map(x->x[i], test_y|>cpu)) for i in 1:tmpLen ]
if TRAIN_WITH_GPU; tmpBase = gpu(tmpBase); end
tmpLoss    = mean([ loss_direct(tmpBase, test_y[i]) |> cpu for i in 1:length(test_y) ])
@info "Baseline Loss: $tmpLoss"


prev_loss = [ loss(test_x[i], test_y[i]) |> cpu for i in 1:length(test_x) ] |> mean;
ps_saved  = deepcopy(collect.(ps));
@info "Initial Loss: $prev_loss"
nCounter  = 0;
nBatchSize= 8192;
lossListTest  = Float64[];
lossListTrain = Float64[];
FILE_TERM_SIGNAL = "/tmp/JULIA_EMERGENCY_STOP"
while true
	if isfile(FILE_TERM_SIGNAL)
		break
	end
	# train
	tmpIndexes = rand(1:length(training_x),nBatchSize);
	if TRAIN_WITH_GPU; tmpIndexes = gpu(tmpIndexes); end
	Flux.train!(
		loss,
		ps,
		zip(training_x[tmpIndexes], training_y[tmpIndexes]),
		opt,
		)
	nCounter += 1
	# current loss
	this_loss = [ loss(test_x[i], test_y[i]) |> cpu for i in 1:length(test_x) ] |> mean
	throttle_loss = [ loss(throttle_x[i], throttle_y[i]) |> cpu for i in 1:length(throttle_x) ] |> mean
	@info "$(Dates.now()) $nCounter/∞ latest loss $throttle_loss / $this_loss"
	push!(lossListTest, this_loss)
	push!(lossListTrain, throttle_loss)
	# record
	if this_loss < 0.95*prev_loss
		ps_saved = deepcopy(collect.(ps));
		prev_loss = this_loss
	end
end

# params for generating orders

const DIRECTION_SHORT = false
const DIRECTION_LONG  = true
TRADE_FEE = 0.04 / 30
mutable struct Order
	Direction::Bool
	PositionPercentage::Float32
	TakeProfit::Float32 # x.xx%, 1.0 means 1%
	StopLoss::Float32 # x.xx%, like -5.0(%)
	end

SWITCH_VERSE_DIRECTION = false
function GenerateP(x::Vector{Vector{Float32}})::Vector{Union{Nothing,Order}}
	tmpPredicts = m.(x)
	tmpPredictsAbs = map(x->abs.(x), tmpPredicts)
	retOrders  = Union{Nothing,Order}[]
	for i in 1:length(tmpPredicts)
		if tmpPredictsAbs[i][1] < GlobalVars.gpThreshold && tmpPredictsAbs[i][2] < GlobalVars.gpThreshold
			push!(retOrders, nothing)
			continue
		end
		tmpDiff = tmpPredictsAbs[i][1] - tmpPredictsAbs[i][2]
		if abs(tmpDiff) < GlobalVars.gpMinDiff
			push!(retOrders, nothing)
			continue
		end
		tmpOrder = Order(
			DIRECTION_LONG,
			Base.Math.tanh(tmpDiff),
			tmpPredicts[i][1],
			tmpPredicts[i][2],
			)
		if tmpDiff < 0
			tmpOrder.Direction = DIRECTION_SHORT
			tmpOrder.PositionPercentage = Base.Math.tanh(-tmpDiff)
			tmpOrder.TakeProfit = tmpPredicts[i][2]
			tmpOrder.StopLoss = tmpPredicts[i][1]
		end
		if SWITCH_VERSE_DIRECTION
			tmpOrder.Direction = !tmpOrder.Direction
			tmpOrder.TakeProfit, tmpOrder.StopLoss = 
				-sign(tmpOrder.TakeProfit) * min(abs.([tmpOrder.TakeProfit, tmpOrder.StopLoss])...),
				-sign(tmpOrder.StopLoss) * max(abs.([tmpOrder.TakeProfit, tmpOrder.StopLoss])...)
		end
		push!(retOrders, tmpOrder)
	end
	return retOrders
	end

# backtest


mutable struct CurrentPosition
	Direction::Bool
	PositionPercentage::Float32
	Price::Float32
	TP::Float32 # xx.x% of that price, long: 102.3% ==> 1.023
	SL::Float32 # xx.x% of that price, short: 105.6% ==> 1.056
	Timestamp::Int32
	end

function RunBacktestSequence(predicts::Vector{Union{Nothing,Order}}, anoRet::Dict{String,Vector})::Vector{Float64}
	listTs   = anoRet["timestamp"][numMiddlefit+numPrev:end]
	@assert length(predicts) == length(listTs)
	listDiff = zeros(length(predicts))
	currentPos = CurrentPosition(false, 0.0, 0.0, 0.0, 0.0, listTs[1])
	tmpTimeout = 3600 * 12
	for i in 2:length(predicts)
		# process previous position
		if currentPos.PositionPercentage > 0.0
			# current prices
			currentHigh = reduce(max, GetBTCHighWhen(listTs[i-1]:listTs[i])) / currentPos.Price # 1.1
			currentLow  = reduce(min, GetBTCLowWhen(listTs[i-1]:listTs[i])) / currentPos.Price # 0.9
			currentClose= GetBTCCloseWhen(listTs[i])
			# check TP/SL
			if currentPos.Direction == DIRECTION_LONG
				if !(currentPos.SL < currentPos.TP)
					@warn "baseline debug mode"
				end
				if currentLow <= (currentPos.SL/currentPos.Price)
					listDiff[i] = (currentPos.SL - currentPos.Price) * currentPos.PositionPercentage
				elseif currentHigh >= (currentPos.TP/currentPos.Price)
					listDiff[i] = (currentPos.TP - currentPos.Price) * currentPos.PositionPercentage
				end
			elseif currentPos.Direction == DIRECTION_SHORT
				if !(currentPos.TP < currentPos.SL)
					@warn "baseline debug mode"
				end
				if currentHigh >= (currentPos.SL/currentPos.Price)
					listDiff[i] = (currentPos.Price - currentPos.SL) * currentPos.PositionPercentage
				elseif currentLow <= (currentPos.TP/currentPos.Price)
					listDiff[i] = (currentPos.Price - currentPos.TP) * currentPos.PositionPercentage
				end
			elseif (listTs[i] - currentPos.Timestamp) >= tmpTimeout
				# timeout trigger
				if currentPos.Direction == DIRECTION_LONG
					listDiff[i] = (currentClose - currentPos.Price) * currentPos.PositionPercentage
				elseif currentPos.Direction == DIRECTION_SHORT
					listDiff[i] = (currentPos.Price - currentClose) * currentPos.PositionPercentage
				end
			elseif !isnothing(predicts[i]) && currentPos.Direction !== predicts[i].Direction
				# opposite direction trigger
				if currentPos.Direction == DIRECTION_LONG
					listDiff[i] = (currentClose - currentPos.Price) * currentPos.PositionPercentage
				elseif currentPos.Direction == DIRECTION_SHORT
					listDiff[i] = (currentPos.Price - currentClose) * currentPos.PositionPercentage
				end
			end
		end
		# post clear
		if !iszero(listDiff[i]) # position cleared
			listDiff[i] -= currentPos.PositionPercentage * currentPos.Price * TRADE_FEE
			currentPos.PositionPercentage = 0.0
		end
		# new position
		if !isnothing(predicts[i])
			# if completely new
			if iszero(currentPos.PositionPercentage)
				currentPos.Direction = predicts[i].Direction
				currentPos.PositionPercentage = predicts[i].PositionPercentage
				currentPos.Price = GetBTCCloseWhen(listTs[i])
				currentPos.TP = currentPos.Price * (1.0 + 0.01*predicts[i].TakeProfit) # 42000 * 102%
				currentPos.SL = currentPos.Price * (1.0 + 0.01*predicts[i].StopLoss) # 39000 * 88%
				currentPos.Timestamp = listTs[i]
			# if same direction
			elseif currentPos.Direction == predicts[i].Direction
				nothing # for now, may add later
			end
		end
	end
	return listDiff
	end

function RunBacktestSequence(fromDate::DateTime, toDate::DateTime)::Vector{Float64}
	testRet = GenerateWindowedViewH3(fromDate, toDate) |> ret2dict
	tmpX = GenerateX(testRet)[numMiddlefit:end, :]
	testX = [ vcat(tmpX[i-numPrev+1:i,:]...) for i in numPrev+1:size(tmpX)[1] ];
	predicts = GenerateP(testX)
	return RunBacktestSequence(predicts, testRet)
	end

