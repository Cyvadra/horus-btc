
using Genie, PlotlyJS

include("./client-config.jl")
include("./config.jl")
include("./functions-ma.jl")
include("./service-FinanceDB.jl")
include("./middleware-results-flexible.jl")
include("./service-block_timestamp.jl")
include("./functions-generate_window.jl")
include("./utils.jl")
labCachePath = "/tmp/julia-lab-plot.html"
numMiddlefit = 12
SWITCH_lab_RANGE_SLIDER = true
lab_color_up = "red"
lab_color_down = "blue"
lab_color_bias = "blue"
lab_color_ma = "purple"
touch(labCachePath)
route("/lab") do
	global cacheTs
	# get params
	n = parse(Int, Genie.params(:num, "14"))
	tmpWindow = parse(Int, Genie.params(:interval, "7200"))
	# check cache
	if round(Int,time()) - cacheTs < 10
		return read(labCachePath, String)
	else
		cacheTs = round(Int,time())
	end
	tmpNow  = now() |> dt2unix
	tmpTs   = min(GetBTCLastTs(), GetLastResultsTimestamp())
	tmpTs   = tmpNow - tmpNow % 300
	tmpTs   = min(GetBTCLastTs(), tmpTs)
	tmpDt   = unix2dt(tmpTs)
	tmpRet  = GenerateWindowedView(Int32(tmpWindow), dt2unix(tmpDt-Day(n)), dt2unix(tmpDt)) |> ret2dict
	listTs  = tmpRet["timestamp"]
	latestH   = reduce( max,
		GetBTCHighWhen(listTs[end]-300:round(Int,time()))
		)
	latestL   = reduce( min,
		filter(x->x>0,
			GetBTCLowWhen(listTs[end]-300:round(Int,time()))
		)
		)
	pricesOpen, pricesHigh, pricesLow, pricesClose = GenerateOHLC(listTs, tmpWindow)
	# plot
	listTs = map(
		x-> string( unix2datetime(x) + Hour(8) ),
		tmpRet["timestamp"]
		)
	listTs = map(
		x-> x[1:end-3],
		listTs
		)
	traces, tmpBaseY = GenerateTraces(tmpRet, simpList, listTs)
	pricesOpen, pricesHigh, pricesLow, pricesClose = plotfit_multi([pricesOpen, pricesHigh, pricesLow, pricesClose], 0:tmpBaseY, tmpBaseY/2)
	push!(traces, 
		PlotlyJS.candlestick(
			x = listTs,
			open = pricesOpen,
			high = pricesHigh,
			low = pricesLow,
			close = pricesClose,
			name = "实际值", yaxis = "实际值")
	)
	push!(traces, PlotlyJS.scatter(
		x = listTs, y = ema(pricesClose,7), name="ema", marker_color="purple")
	)
	push!(traces, PlotlyJS.scatter(
		x = listTs, y = ma(pricesClose,7), name="ma", marker_color="yellow")
	)
	f = open(labCachePath, "w")
	PlotlyJS.savefig(f,
		PlotlyJS.plot(
			traces,
			Layout(
				title_text = listTs[end] * " $latestH $latestL",
				xaxis_title_text = "时间",
				xaxis_rangeslider_visible = SWITCH_lab_RANGE_SLIDER,
			)
		);
		height = round(Int, 1080*3),
		format = "html"
	)
	close(f)
	f = read(labCachePath, String)
	f = replace(f, "https://cdn.plot.ly/plotly-2.3.0.min.js" => "http://cdn.git2.biz/plotly-2.3.0.min.js")
	f = replace(f, "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js" => "http://cdn.git2.biz/MathJax.js")
	f = replace(f, "<meta chartset" => """<meta http-equiv="refresh" content="360" charset""")
	return f
	end

function GenerateOHLC(listTs::Vector, tmpWindow::Int)
	pricesOpenOri  = [ GetBTCOpenWhen(ts-tmpWindow) for ts in listTs ]
	if findlast(x->iszero(x), pricesOpenOri) != nothing
		syncBitcoin()
		pricesOpenOri  = [ GetBTCOpenWhen(ts-tmpWindow) for ts in listTs ]
	end
	pricesCloseOri = GetBTCCloseWhen(listTs)
	pricesHighOri = [ reduce(max, GetBTCHighWhen(ts-tmpWindow+1:ts)) for ts in listTs ]
	pricesLowOri  = [ reduce(min, GetBTCLowWhen(ts-tmpWindow+1:ts)) for ts in listTs ]
	# Heikin-Ashi
	pricesClose = (pricesOpenOri + pricesCloseOri + pricesHighOri + pricesLowOri) ./ 4
	pricesOpen = zeros(length(pricesClose))
	pricesOpen[1] = pricesOpenOri[1]
	for i in 2:length(pricesOpen)
		pricesOpen[i] = (pricesOpen[i-1] + pricesCloseOri[i-1]) / 2
	end
	pricesHigh = [ max(pricesHighOri[i], pricesOpen[i], pricesClose[i]) for i in 1:length(pricesOpen) ]
	pricesLow = [ min(pricesLowOri[i], pricesOpen[i], pricesClose[i]) for i in 1:length(pricesOpen) ]
	if findlast(x->iszero(x), pricesOpen) != nothing
		tmpVal = findlast(x->!iszero(x), pricesOpen)
		pricesOpen[tmpVal:end]  .= pricesOpen[tmpVal-1]
		pricesHigh[tmpVal:end]  .= pricesHigh[tmpVal-1]
		pricesLow[tmpVal:end]   .= pricesLow[tmpVal-1]
		pricesClose[tmpVal:end] .= pricesClose[tmpVal-1]
	end
	return pricesOpen, pricesHigh, pricesLow, pricesClose
	end

function GenerateTracesSimp(tmpRet::Dict, tmpKeys::Vector{String}, axisX::Vector, doStandardization::Bool=true) # Vector{GenericTrace}, tmpBaseY
	singleHeight = 100
	baseList = log.(tmpRet["amountTotalTransfer"])
	traces = GenericTrace[]
	tmpBaseY = 0
	# main lines
	for i in 1:length(tmpKeys)
		s = tmpKeys[i]
		tmpList = log.(tmpRet[s])
		if doStandardization
			tmpList .-= baseList[i]
		end
		tmpList = plotfit(tmpList, -singleHeight:singleHeight, tmpBaseY)
		tmpColor = lab_color_up
		if i % 2 == 0
			tmpColor = lab_color_down
			tmpBaseY += 1.1singleHeight
		end
		push!(traces, 
			PlotlyJS.scatter(
				x = axisX, y = ema(tmpList,3),
				name = translateDict[s],
				marker_color = tmpColor,
			)
		)
	end
	tmpBaseY -= 1.1singleHeight
	tmpBaseY = round(Int, tmpBaseY)
	return traces, tmpBaseY
	end

function GenerateTracesFull(tmpRet::Dict, tmpKeys::Vector{String}, axisX::Vector, doStandardization::Bool=true) # Vector{GenericTrace}, tmpBaseY
	singleHeight = 100
	baseList = log.(tmpRet["amountTotalTransfer"])
	traces = GenericTrace[]
	tmpBaseY = 0
	# main lines
	for i in 1:length(tmpKeys)
		s = tmpKeys[i]
		tmpList = log.(tmpRet[s])
		if doStandardization
			tmpList .-= baseList[i]
		end
		# tmpList     = plotfit(tmpList, -singleHeight:singleHeight, tmpBaseY)
		tmpListMa   = ema(tmpList, numMiddlefit)
		tmpListBias = tmpList .- tmpListMa
		push!(traces, 
			PlotlyJS.scatter(
				x = axisX, y = plotfit(tmpListMa, -singleHeight:singleHeight, tmpBaseY),
				name = translateDict[s]*"-ma",
				marker_color = lab_color_ma,
			)
		)
		push!(traces, 
			PlotlyJS.scatter(
				x = axisX, y = plotfit(tmpListBias, -singleHeight:singleHeight, tmpBaseY),
				name = translateDict[s]*"-bias",
				marker_color = lab_color_bias,
			)
		)
		tmpBaseY += 1.3singleHeight
	end
	tmpBaseY -= 1.3singleHeight
	tmpBaseY = round(Int, tmpBaseY)
	return traces, tmpBaseY
	end
