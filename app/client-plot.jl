include("./auth.jl")

using HTTP
using JSON
using PlotlyJS
using Dates

serviceURL = "http://localhost:8080/sequence"


HTTP.get("http://baidu.com") # precompile HTTP
function normalise(v::Vector, rng::UnitRange)::Vector
	v = deepcopy(v) .+ 0.00
	s = sort(v)
	vMin, vMax = s[1], s[end]
	vBias = vMax - vMin
	v .-= vMin
	v ./= vBias / (rng[end] - rng[1])
	v .+= rng[1]
	return v
	end

singleHeight = 100
percentCross = 0
function GetView()
	tmpHeightBase = singleHeight
	d = String(HTTP.get(serviceURL*"?session=$(GenerateScript())").body) |> JSON.Parser.parse
	tmpRet = d["results"]
	listTs = map(x->x["timestamp"], tmpRet)
	# baseList  = map(x->x["numTotalActive"], tmpRet)
	tmpFields = tmpRet[1] |> keys |> collect |> sort
	traces = GenericTrace[]
	for sym in tmpFields
		tmpList  = map(x->x[sym], tmpRet) #./ baseList
		tmpList  = normalise(tmpList, tmpHeightBase:tmpHeightBase+singleHeight)
		push!(traces, 
			PlotlyJS.scatter(x = listTs, y = tmpList,
				name = string(sym),
			)
		)
		tmpHeightBase += singleHeight
	end
	prices = normalise(d["prices"], singleHeight:tmpHeightBase)
	push!(traces, 
		PlotlyJS.scatter(x = listTs, y = prices,
			name = "actual", marker_color = "black", yaxis = "actual")
	)
	PlotlyJS.plot(
		traces,
		Layout(
			title_text = string(unix2datetime(listTs[end])+Hour(8)) * " $(d["latestH"]) $(d["latestL"])",
			xaxis_title_text = "timestamp",
		)
	)
	end


