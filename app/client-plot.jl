include("./auth.jl")
include("./client-config.jl")

using HTTP
using JSON
using PlotlyJS
using DataFrames
using Statistics
using Dates

serviceURL = "http://localhost:8080/sequence"

HTTP.get("http://baidu.com") # precompile HTTP

function GetData(num::Int=5, intervalSecs::Int=7200)::Dict
	tmpUrl = serviceURL*"?session=$(GenerateScript())&num=$num&interval=$intervalSecs"
	d = String(HTTP.get(tmpUrl).body) |> JSON.Parser.parse
	return d
	end
function GetView(d::Dict)
	tmpRet = d["results"]
	listTs = tmpRet["timestamp"]
	baseList = tmpRet["amountTotalTransfer"]
	tmpKeys = tmpRet |> keys |> collect |> sort
	filter!(x->!(x in ["timestamp", "amountTotalTransfer"]), tmpKeys)
	traces = GenericTrace[]
	for s in tmpKeys
		tmpList  = tmpRet[s] #./ baseList
		tmpList  = plotfit(tmpList, -singleHeight:singleHeight, 0.0)
		push!(traces, 
			PlotlyJS.scatter(
				x = listTs, y = tmpList,
				name = translateDict[s],
				# marker_color = "rgba($(rand(133:255)), $(rand(133:255)), $(rand(133:255)), 0.7)"
			)
		)
	end
	prices = plotfit(d["prices"], -singleHeight:singleHeight, 0)
	baseList = plotfit(baseList, -singleHeight:singleHeight, 0)
	push!(traces, 
		PlotlyJS.scatter(x = listTs, y = baseList,
			name = "amount", marker_color = "red", yaxis = "amount")
	)
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
function GetViewStd(d::Dict)
	tmpRet = d["results"]
	listTs = deepcopy(tmpRet["timestamp"])
	baseList  = tmpRet["amountTotalTransfer"]
	tmpRet = d["results"]
	listTs = tmpRet["timestamp"]
	tmpKeys = tmpRet |> keys |> collect |> sort
	filter!(x->!(x in ["timestamp", "amountTotalTransfer"]), tmpKeys)
	traces = GenericTrace[]
	for s in tmpKeys
		replace!(tmpRet[s], nothing=>0.0)
		tmpList  = tmpRet[s] ./ baseList
		tmpList  = plotfit(tmpList, -singleHeight:singleHeight, 0)
		push!(traces, 
			PlotlyJS.scatter(
				x = listTs,
				y = tmpList,
				name = translateDict[s],
				# mode = "markers",
				# marker_size = rand(1:20),
			)
		)
	end
	prices = plotfit(d["prices"], -singleHeight:singleHeight, 0)
	baseList = plotfit(baseList, -singleHeight:singleHeight, 0)
	push!(traces, 
		PlotlyJS.scatter(x = listTs, y = prices,
			name = "actual", marker_color = "black", yaxis = "actual")
	)
	push!(traces, 
		PlotlyJS.scatter(x = listTs, y = baseList,
			name = "amount", marker_color = "red", yaxis = "amount")
	)
	PlotlyJS.plot(
		traces,
		Layout(
			title_text = string(unix2datetime(listTs[end])+Hour(8)) * " $(d["latestH"]) $(d["latestL"])",
			xaxis_title_text = "timestamp",
		)
	)
	end

function GetView()
	d = GetData()
	furtherCalculate!(d)
	GetView(d)
	end
function GetViewTraditional()
	d = GetData()
	furtherCalculate!(d)
	tmpRet = d["results"]
	listTs = tmpRet["timestamp"]
	delete!(tmpRet, "timestamp")
	# baseList  = map(x->x["numTotalActive"], tmpRet)
	tmpFields = tmpRet |> keys |> collect |> sort
	traces = GenericTrace[]
	for s in tmpFields
		if s in hiddenList
			continue
		end
		tmpList  = tmpRet[s] #./ baseList
		if occursin("amountRealized", s)
			tmpList .*= 1e5
		end
		push!(traces, 
			PlotlyJS.scatter(x = listTs, y = tmpList,
				name = translateDict[s],
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

function SimpView(numDays::Int=3, intervalSecs::Int=7200)
	d = GetData(numDays, intervalSecs)
	return SimpView(d)
	end
function SimpView(d::Dict)
	tmpRet = d["results"]
	listTs = map(
		x-> string( unix2datetime(x) + Hour(8) ),
		tmpRet["timestamp"]
		)
	# listTs = map(
	# 	x-> x[end-13:end-9] * "-" * x[end-7:end-3],
	# 	listTs
	# 	)
	baseList = tmpRet["amountTotalTransfer"]
	tmpKeys = simpList
	traces = GenericTrace[]
	tmpBaseY = 0
	for i in 1:length(tmpKeys)
		s = tmpKeys[i]
		tmpList = tmpRet[s]
		tmpList = plotfit_ma(tmpList, -100:100, tmpBaseY, 72)
		tmpColor = "red"
		if i % 2 == 0
			tmpColor = "blue"
			tmpBaseY += 2singleHeight
		end
		push!(traces, 
			PlotlyJS.scatter(
				x = listTs, y = tmpList,
				name = translateDict[s],
				marker_color = tmpColor,
			)
		)
	end
	tmpBaseY -= singleHeight
	prices = plotfit_ma(d["prices"], 0:tmpBaseY, tmpBaseY/2, 72)
	push!(traces, 
		PlotlyJS.scatter(x = listTs, y = prices,
			name = "实际值", marker_color = "black", yaxis = "实际值")
	)
	PlotlyJS.plot(
		traces,
		Layout(
			title_text = listTs[end] * "$(tmpRet["timestamp"][2]-tmpRet["timestamp"][1])",
			xaxis_title_text = "时间",
		)
	)
	end