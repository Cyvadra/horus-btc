
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

function GenerateX(anoRet::Dict{String,Vector})::Matrix{Float32}
	baseList  = anoRet["amountTotalTransfer"]
	sequences = Vector[]
	for k in dnnList
		tmpList = anoRet[k] ./ baseList
		tmpList = middlefit(tmpList, numMa)
		push!(sequences,
			Vector{Float32}(tmpList)
			)
	end
	return hcat(sequences...)
	end

fromDate  = DateTime(2019,3,1,0)
toDate    = DateTime(2022,3,31,0)
anoRet    = GenerateWindowedViewH3(fromDate, toDate) |> ret2dict
oriX = GenerateX(anoRet)
oriY = GenerateY(anoRet)

