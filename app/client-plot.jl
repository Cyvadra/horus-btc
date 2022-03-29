include("./auth.jl")

using HTTP
using JSON
using PlotlyJS
using Dates

serviceURL = "http://localhost:8080/sequence"
hiddenList = String[
		"amountRecentD3", "numTotalRows", "amountTotalTransfer",
		"numWakeupW1Sending", "numWakeupW1Byuing",
		"numWakeupM1Sending", "numWakeupM1Byuing",
		"amountRecentD3Sending", "amountRecentD3Buying",
		"numRecentD3Sending", "numRecentD3Buying",
		"numTotalActive", "timestamp"
	]

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

priceRange = 10000:100000
function GetView()
	d = String(HTTP.get(serviceURL*"?session=$(GenerateScript())").body) |> JSON.Parser.parse
	tmpRet = d["results"]
	listTs = map(x->x["timestamp"], tmpRet)
	# baseList  = map(x->x["numTotalActive"], tmpRet)
	tmpFields = tmpRet[1] |> keys |> collect
	traces = GenericTrace[]
	for sym in tmpFields
		if sym in hiddenList
			continue
		end
		tmpList  = map(x->x[sym], tmpRet) #./ baseList
		if occursin("amountRealized", string(sym))
			tmpList .*= 1e5
		end
		# tmpList  = normalise(tmpList, displatRange)
		push!(traces, 
			PlotlyJS.scatter(x = listTs, y = tmpList,
				name = string(sym),
			)
		)
	end
	prices = normalise(d["prices"], priceRange)
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


