
include("./config.jl");
include("./utils.jl");
include("./cache-generated.jl");
include("./service-block_timestamp.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");
include("./functions-ma.jl");
include("./client-config.jl");

using Dates

TableResults.Open(true)
@show GetLastResultsID()

numMa    = 12 # 24h
tmpSyms  = ResultCalculations |> fieldnames |> collect

function GenerateSequences(tmpRet::Vector{ResultCalculations})::Matrix{Float64}
	anoRet   = Dict{String,Vector}()
	for s in tmpSyms
		if occursin("Billion", string(s))
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet) .* 1e9
		else
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet)
		end
	end
	baseList  = anoRet["amountTotalTransfer"]
	sequences = Vector[]
	for k in dnnList
		tmpList = anoRet[k] ./ baseList
		tmpBase = ma(tmpList, numMa)
		tmpList = histofit(tmpList ./ tmpBase)
		push!(sequences,
			tmpList
			)
	end
	return hcat(sequences...)
	end

fromDate  = DateTime(2019,3,1,0)
toDate    = DateTime(2022,3,31,0)
@time res = GenerateWindowedViewH3(fromDate, toDate) |> GenerateSequences
for i in 1:5
	res = vcat(res,
		GenerateWindowedViewH3(fromDate + Minute(30i), toDate + Minute(30i)) |> GenerateSequences
		)
end












