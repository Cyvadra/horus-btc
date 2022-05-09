
include("./config.jl");
include("./utils.jl");
include("./cache-generated.jl");
include("./service-block_timestamp.jl");
include("./service-FinanceDB.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");
include("./functions-ma.jl");
include("./client-config.jl");

using Dates
using Statistics
using Flux

TableResults.Open(true)
@show GetLastResultsID()

numMa    = 16 # 48h
postSecs = 10800 # predict 3h
tmpSyms  = ResultCalculations |> fieldnames |> collect
const DIRECTION_SHORT = false
const DIRECTION_LONG  = true
TRADE_FEE = 0.0008

mutable struct Order
	Direction::Bool
	PositionPercentage::Float32
	TakeProfit::Float32
	StopLoss::Float32
	end

function ret2dict(tmpRet::Vector{ResultCalculations})::Dict{String,Vector}
	anoRet   = Dict{String,Vector}()
	for s in tmpSyms
		if occursin("Billion", string(s))
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet) .* 1e9
		else
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet)
		end
	end
	return anoRet
	end

function GenerateY(ts, postSecs::Int)
	ratioSL = 1.05
	ratioTP = 0.95
	c = middle(GetBTCCloseWhen(ts-postSecs:ts))
	h = reduce(max, GetBTCHighWhen(ts+60:ts+postSecs))
	l = reduce(min, GetBTCLowWhen(ts+60:ts+postSecs))
	h = 100*abs(h - c) / c
	l = 100*abs(c - l) / c
	if h > l
		return [h*ratioTP, -l*ratioSL]
	else
		return [-l*ratioTP, h*ratioSL]
	end
	end
function GenerateY(anoRet::Dict{String,Vector})
	tsList = anoRet["timestamp"]
	return hcat([ GenerateY(ts, postSecs) for ts in tsList ]...)' |> collect
	end

function GenerateP(anoRet::Dict{String,Vector})::Vector{Union{Nothing,Order}}
	baseList  = anoRet["amountTotalTransfer"]
	tmpProfit = anoRet["amountRealizedProfitBillion"] ./ baseList
	tmpLoss   = anoRet["amountRealizedLossBillion"] ./ baseList
	biasProfit = tmpProfit ./ sma(tmpProfit,8)
	biasLoss   = tmpLoss ./ sma(tmpLoss,8)
	prevState  = biasProfit[1] >= biasLoss[1]
	tmpOrder   = Order(false, 0.0, 0.0, 0.0)
	retOrders  = Union{Nothing,Order}[nothing]
	for i in 2:length(baseList)
		thisState = biasProfit[i] >= biasLoss[i]
		if thisState !== prevState
			push!(retOrders, deepcopy(tmpOrder))
			if biasProfit[i] >= biasLoss[i]
				retOrders[i].Direction = DIRECTION_SHORT
			else
				retOrders[i].Direction = DIRECTION_LONG
			end
			retOrders[i].PositionPercentage = abs(biasProfit[i]-biasLoss[i])
		else
			push!(retOrders, nothing)
		end
		prevState = biasProfit[i] >= biasLoss[i]
	end
	return retOrders
	end

fromDate  = DateTime(2019,3,1,0)
toDate    = DateTime(2022,3,31,0)
anoRet    = GenerateWindowedViewH3(fromDate, toDate) |> ret2dict
oriX = GenerateX(anoRet)
oriY = GenerateY(anoRet)

mutable struct CurrentPosition
	Direction::Bool
	PositionPercentage::Float32
	Price::Float32
	TP::Float32
	SL::Float32
	Timestamp::Int32
	end

function RunBacktest(predicts::Vector{Union{Nothing,Order}}, anoRet::Dict{String,Vector})::Vector{Float64}
	@assert length(predicts) == length(anoRet["timestamp"])
	listNet = ones(length(predicts)) .* 100
	listTs  = anoRet["timestamp"]
	currentPos = CurrentPosition(false, 0.0, 0.0, 0.0, 0.0, listTs[1])
	for i in 2:length(predicts)
		listNet[i] = listNet[i-1]
		if currentPos.PositionPercentage > 0.0
			if currentPos.Direction == DIRECTION_SHORT
				listNet[i] = listNet[i-1] + 
					( currentPos.Price - GetBTCHighWhen(listTs[i]) ) * currentPos.PositionPercentage
			elseif currentPos.Direction == DIRECTION_LONG
				listNet[i] = listNet[i-1] + 
					( GetBTCLowWhen(listTs[i]) - currentPos.Price ) * currentPos.PositionPercentage
			end
			listNet[i] -= currentPos.PositionPercentage * GetBTCCloseWhen(listTs[i]) * TRADE_FEE
			currentPos.PositionPercentage = 0.0
		end
		if !isnothing(predicts[i])
			currentPos.Direction = predicts[i].Direction
			currentPos.PositionPercentage = predicts[i].PositionPercentage
			currentPos.Price = GetBTCCloseWhen(listTs[i])
			currentPos.Timestamp = listTs[i]
		end
	end
	return listNet
	end
