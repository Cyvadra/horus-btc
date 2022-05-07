
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

mutable struct Order
	Enabled::Bool
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
	c = middle(GetBTCCloseWhen(ts-postSecs:ts))
	h = reduce(max, GetBTCHighWhen(ts+60:ts+postSecs))
	l = reduce(min, GetBTCLowWhen(ts+60:ts+postSecs))
	return [ -100*abs(c - l) / c, 100*abs(h - c) / c ]
	end
function GenerateY(anoRet::Dict{String,Vector})::Matrix{Float32}
	tsList    = anoRet["timestamp"]
	return hcat([ GenerateY(ts, postSecs) for ts in tsList ]...)' |> collect
	end

function GenerateP(anoRet::Dict{String,Vector})::Vector{Order}
	baseList  = anoRet["amountTotalTransfer"]
	tmpProfit = anoRet["amountRealizedProfitBillion"] ./ baseList
	tmpLoss   = anoRet["amountRealizedLossBillion"] ./ baseList
	biasProfit = tmpProfit ./ sma(tmpProfit,8)
	biasLoss   = tmpLoss ./ sma(tmpLoss,8)
	prevState  = biasProfit[1] >= biasLoss[1]
	tmpOrder   = Order(false, false, 0.0, 0.0, 0.0)
	retOrders  = [ deepcopy(tmpOrder) for i in 1:length(baseList) ]
	for i in 2:length(baseList)
		thisState = biasProfit[i] >= biasLoss[i]
		if thisState !== prevState
			retOrders[i].Enabled = true
			retOrders[i].PositionPercentage = abs(biasProfit[i]-biasLoss[i])
			if biasProfit[i] >= biasLoss[i]
				retOrders[i].Direction = DIRECTION_SHORT
			else
				retOrders[i].Direction = DIRECTION_LONG
			end
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

function RunBacktest(predicts::Vector{Order})::Vector{Float64}
	prevPosition  = false
	prevDirection = DIRECTION_SHORT
	prevAmount    = 0.0
	prevPrice     = 0.0
	@assert length(predicts) == size(oriY)[1]
	listNet = ones(length(predicts)) .* 100
	for i in 1:length(predicts)
		if predicts[i].Enabled
			# execute order
			if prevPosition
				if prevDirection == predicts[i].Direction
					# continue
				else
					# switch
					listNet[i]
					prevPrice
				end
			else
				# init position
				prevPosition  = true
				prevDirection = predicts[i].Direction
				prevAmount    = predicts[i].PositionPercentage
			end
		else
			# calculate current net worth
			listNet[i] = listNet[i-1]
		end
	end
	return listNet
	end
