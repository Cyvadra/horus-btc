
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

fromDate  = DateTime(2019,11,1,0)
toDate    = DateTime(2022,4,30,23,59,59)
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
			Dense(inputSize, 64, tanh_fast),
			Dense(64, 8, relu),
			Dense(8, yLength),
		)
if TRAIN_WITH_GPU; m = gpu(m); end
ps = Flux.params(m);

opt        = ADADelta(0.92, 1e-9);
tx, ty     = (test_x[15], test_y[15]);
loss(x, y) = Flux.mae(m(x), y);
evalcb     = () -> @show loss(tx, ty);

tmpLen     = length(test_y[1]);
tmpBase    = [ mean(map(x->x[i], test_y)) for i in 1:tmpLen ]
if TRAIN_WITH_GPU; tmpBase = gpu(tmpBase); end
tmpLoss    = mean([ Flux.mae(tmpBase, test_y[i]) |> cpu for i in 1:length(test_y) ])
@info "Baseline Loss: $tmpLoss"


prev_loss = [ Flux.mae(m(test_x[i]), test_y[i]) |> cpu for i in 1:length(test_x) ] |> mean;
ps_saved  = deepcopy(collect(ps));
@info "Initial Loss: $prev_loss"
nCounter  = 0;
lossList  = [];
while true
	# train
	@info "$nCounter/∞ $(Dates.now())"
	Flux.train!(loss, ps, data, opt)
	nCounter += 1
	# current loss
	this_loss = [ Flux.mae(m(test_x[i]), test_y[i]) |> cpu for i in 1:length(test_x) ] |> mean
	@info "latest loss $this_loss"
	push!(lossList, this_loss)
	# record
	if this_loss < 0.98*prev_loss
		ps_saved = deepcopy(collect(ps));
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

