
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

numPrev  = 5 # 36h
postSecs = 10800 # predict 3h
tmpSyms  = ResultCalculations |> fieldnames |> collect
numMiddlefit = 12 # 72h
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

function GenerateX(anoRet::Dict{String,Vector})::Matrix{Float32}
	sequences = Vector[]
	for k in dnnList
		push!(sequences,
			ema(
				middlefit(
				safe_log.(Vector{Float32}(anoRet[k])),
				numMiddlefit
				), 5
			)
		)
	end
	return hcat(sequences...)
	end

fromDate  = DateTime(2019,2,1,0)
toDate    = DateTime(2022,1,31,23,59,59)
fromDateTest = DateTime(2022,3,15,0)
toDateTest   = DateTime(2022,5,20,0)

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

# backtest

mutable struct CurrentPosition
	Direction::Bool
	PositionPercentage::Float32
	Price::Float32
	TP::Float32 # direct price value
	SL::Float32 # xxxxx.xx
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

# under construction
function RunBacktestSequence(fromDate::DateTime, toDate::DateTime)::Vector{Float64}
	testRet = GenerateWindowedViewH3(fromDate, toDate) |> ret2dict
	tmpX = GenerateX(testRet)[numMiddlefit:end, :]
	# tmpY = GenerateY(testRet)[numMiddlefit:end, :]
	# testX = [ vcat(tmpX[i-numPrev+1:i,:]..., tmpY[i-1]) for i in numPrev+1:size(tmpX)[1] ];
	# predicts = GenerateP(testX)
	# return RunBacktestSequence(predicts, testRet)
	end

