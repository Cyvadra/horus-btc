
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
	# ratioSL = 1.05
	# ratioTP = 0.95
	c = middle(GetBTCCloseWhen(ts-900:ts))
	h = reduce(max, GetBTCHighWhen(ts+60:ts+postSecs))
	l = reduce(min, GetBTCLowWhen(ts+60:ts+postSecs))
	h = 100 * (h - c) / c
	l = 100 * (l - c) / c
	return [h, l]
	end
function GenerateY(anoRet::Dict{String,Vector})
	tsList = anoRet["timestamp"]
	return hcat([ GenerateY(ts, postSecs) for ts in tsList ]...)' |> collect
	end

function GenerateX(anoRet::Dict{String,Vector})::Matrix{Float32}
	sequences = Vector[]
	for k in dnnList
		push!(sequences,
			Vector{Float32}(middlefit(anoRet[k], numMiddlefit))
			)
	end
	return hcat(sequences...)
	end

fromDate  = DateTime(2020,7,1,0)
toDate    = DateTime(2022,3,31,23,59,59)
anoRet    = GenerateWindowedViewH3(fromDate, toDate) |> ret2dict
oriX = GenerateX(anoRet)[numMiddlefit:end, :]
oriY = GenerateY(anoRet)[numMiddlefit:end, :]

X = [ vcat(oriX[i-numPrev+1:i,:]...) for i in numPrev+1:size(oriX)[1] ];
Y = [ oriY[i,:] for i in numPrev+1:size(oriY)[1] ];

@showprogress for i in 1:5
	tmpRet  = GenerateWindowedViewH3(
		fromDate + Minute(30i),
		toDate + Minute(30i)
		) |> ret2dict
	tmpX = GenerateX(tmpRet)[numMiddlefit:end, :]
	tmpY = GenerateY(tmpRet)[numMiddlefit:end, :]
	append!(X, [ vcat(tmpX[i-numPrev+1:i,:]...) for i in numPrev+1:size(tmpX)[1] ])
	append!(Y, [ tmpY[i,:] for i in numPrev+1:size(tmpY)[1] ])
	@assert length(X) == length(Y)
end

tmpInds = reduce(vcat,
	[ collect(1+i:6:length(X)+i) for i in 0:5 ]
	)
X = X[tmpInds] |> deepcopy
Y = Y[tmpInds] |> deepcopy

TRAIN_WITH_GPU = true

# Prepare Data
tmpMidN = round(Int, length(X)*0.8)
tmpIndexes = sortperm(rand(tmpMidN))
training_x = deepcopy(X[tmpIndexes])
training_y = deepcopy(Y[tmpIndexes])
test_x = deepcopy(X[tmpMidN+1:end])
test_y = deepcopy(Y[tmpMidN+1:end])
if TRAIN_WITH_GPU
	training_x = gpu(training_x)
	training_y = gpu(training_y)
	test_x = gpu(test_x)
	test_y = gpu(test_y)
end

yLength   = length(Y[end])
inputSize = length(X[1])
data      = zip(training_x, training_y)

nThrottle  = 30

m = Chain(
			Dense(inputSize, 16, tanh_fast),
			Dense(16, 4, relu),
			Dense(4, yLength),
		)
if TRAIN_WITH_GPU; m = gpu(m); end
ps = Flux.params(m);

opt        = ADADelta(0.92, 1e-9);
tx, ty     = (test_x[15], test_y[15]);
evalcb     = () -> @show loss(tx, ty);
loss(x, y) = Flux.mse(m(x), y);

tmpLen     = length(test_y[1]);
tmpBase    = [ mean(map(x->x[i], test_y)) for i in 1:tmpLen ]
if TRAIN_WITH_GPU; tmpBase = gpu(tmpBase); end
tmpLoss    = mean([ Flux.mse(tmpBase, test_y[i]) |> cpu for i in 1:length(test_y) ])
@info "Baseline Loss: $tmpLoss"


prev_loss = [ Flux.mse(m(test_x[i]), test_y[i]) |> cpu for i in 1:length(test_x) ] |> mean;
ps_saved  = deepcopy(collect(ps));
@info "Initial Loss: $prev_loss"
nCounter  = 0;
while true
	# train
	@info "$nCounter/∞"
	Flux.train!(loss, ps, data, opt; cb = Flux.throttle(evalcb, nThrottle))
	nCounter += 1
	# current loss
	this_loss = [ Flux.mse(m(test_x[i]), test_y[i]) |> cpu for i in 1:length(test_x) ] |> mean
	@info "latest loss $this_loss"
	@info now()
	# record
	if this_loss < 0.98*prev_loss
		ps_saved = deepcopy(collect(ps));
		prev_loss = this_loss
	end
end

# params for generating orders

const DIRECTION_SHORT = false
const DIRECTION_LONG  = true
TRADE_FEE = 0.0008
mutable struct Order
	Direction::Bool
	PositionPercentage::Float32
	TakeProfit::Float32
	StopLoss::Float32
	end

function GenerateP(x::Vector{Vector{Float32}})::Vector{Union{Nothing,Order}}
	tmpThreshold = Float32(0.1)
	tmpMinDiff   = Float32(0.5)
	tmpPredicts = m.(x)
	tmpPredictsAbs = map(x->abs.(x), tmpPredicts)
	retOrders  = Union{Nothing,Order}[]
	for i in 1:length(tmpPredicts)
		if tmpPredictsAbs[i][1] < tmpThreshold || tmpPredictsAbs[i][2] < tmpThreshold
			push!(retOrders, nothing)
			continue
		end
		tmpDiff = tmpPredictsAbs[i][1] - tmpPredictsAbs[i][2]
		if abs(tmpDiff) < tmpMinDiff
			push!(retOrders, nothing)
			continue
		end
		tmpOrder = Order(
			DIRECTION_LONG,
			Base.Math.tanh(tmpDiff),
			0.0,
			0.0,
			)
		if tmpDiff < 0
			tmpOrder.Direction = DIRECTION_SHORT
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
	TP::Float32
	SL::Float32
	Timestamp::Int32
	end

function RunBacktestSequence(predicts::Vector{Union{Nothing,Order}}, anoRet::Dict{String,Vector})::Vector{Float64}
	listTs   = anoRet["timestamp"][numMiddlefit+numPrev:end]
	@assert length(predicts) == length(listTs)
	listDiff = zeros(length(predicts))
	currentPos = CurrentPosition(false, 0.0, 0.0, 0.0, 0.0, listTs[1])
	for i in 2:length(predicts)
		if currentPos.PositionPercentage > 0.0
			if currentPos.Direction == DIRECTION_SHORT
				listDiff[i] = ( currentPos.Price - GetBTCHighWhen(listTs[i]) ) * currentPos.PositionPercentage
			elseif currentPos.Direction == DIRECTION_LONG
				listDiff[i] = ( GetBTCLowWhen(listTs[i]) - currentPos.Price ) * currentPos.PositionPercentage
			end
			listDiff[i] -= currentPos.PositionPercentage * GetBTCCloseWhen(listTs[i]) * TRADE_FEE
			currentPos.PositionPercentage = 0.0
		end
		if !isnothing(predicts[i])
			currentPos.Direction = predicts[i].Direction
			currentPos.PositionPercentage = predicts[i].PositionPercentage
			currentPos.Price = GetBTCCloseWhen(listTs[i])
			currentPos.Timestamp = listTs[i]
		end
	end
	return listDiff
	end
