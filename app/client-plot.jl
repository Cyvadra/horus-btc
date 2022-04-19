include("./auth.jl")

using HTTP
using JSON
using PlotlyJS
using DataFrames
using Statistics
using Dates

serviceURL = "http://localhost:8080/sequence"

hiddenList = String[
	"amountRecentD3", "numTotalRows", "amountTotalTransfer",
	"numWakeupW1Sending", "numWakeupW1Byuing",
	"numWakeupM1Sending", "numWakeupM1Byuing",
	"amountRecentD3Sending", "amountRecentD3Buying",
	"numRecentD3Sending", "numRecentD3Buying",
	"numTotalActive", "timestamp",
	"amountWithdrawPercentAbove95", "amountSupplierBalanceAbove95",
	]
translateDict = Dict{String,String}(
	"amountChargePercentBelow10" => "大户充值",
	"amountChargePercentBelow25" => "大额充值25",
	"amountChargePercentBelow50" => "中额充值50",
	"amountChargePercentBelow80" => "中额充值80",
	"amountChargePercentBelow95" => "老客充值",
	"amountChargePercentEquals100" => "净增新额",
	"numChargePercentBelow10" => "大户充值计数",
	"numChargePercentBelow25" => "大额充值计数25",
	"numChargePercentBelow50" => "中额充值计数50",
	"numChargePercentBelow80" => "中额充值计数80",
	"numChargePercentBelow95" => "老客充值计数",
	"numChargePercentEquals100" => "新户数量",
	"amountContinuousD1Buying" => "日内买入",
	"amountContinuousD1Sending" => "日内卖出",
	"amountContinuousD3Buying" => "三日买入",
	"amountContinuousD3Sending" => "三日卖出",
	"amountContinuousW1Buying" => "一周买入",
	"amountContinuousW1Sending" => "一周卖出",
	"numContinuousD1Buying" => "日内买入计数",
	"numContinuousD1Sending" => "日内卖出计数",
	"numContinuousD3Buying" => "三日买入计数",
	"numContinuousD3Sending" => "三日卖出计数",
	"numContinuousW1Buying" => "一周买入计数",
	"numContinuousW1Sending" => "一周卖出计数",
	"amountRealizedLossBillion" => "止损总额",
	"amountRealizedProfitBillion" => "止盈总额",
	"amountRecentD3Buying" => "近期买入",
	"amountRecentD3Sending" => "近期卖出",
	"numRealizedLoss" => "止损计数",
	"numRealizedProfit" => "止盈计数",
	"numRecentD3Buying" => "近期买入计数",
	"numRecentD3Sending" => "近期卖出计数",
	"amountSupplierBalanceAbove95" => "大户供应",
	"amountSupplierBalanceBelow20" => "散户供应20",
	"amountSupplierBalanceBelow40" => "散户供应40",
	"amountSupplierBalanceBelow60" => "中额供应60",
	"amountSupplierBalanceBelow80" => "中额供应80",
	"amountTotalTransfer" => "区块交易总额",
	"amountWakeupM1Buying" => "休眠买入M1",
	"amountWakeupM1Sending" => "休眠卖出M1",
	"amountWakeupW1Buying" => "休眠买入W1",
	"amountWakeupW1Sending" => "休眠卖出W1",
	"numWakeupM1Buying" => "休眠买入M1计数",
	"numWakeupM1Sending" => "休眠卖出M1计数",
	"numWakeupW1Buying" => "休眠买入W1计数",
	"numWakeupW1Sending" => "休眠卖出W1计数",
	"amountWithdrawPercentAbove80" => "账户撤资80",
	"amountWithdrawPercentAbove95" => "账户撤资清退",
	"amountWithdrawPercentBelow10" => "小额提现10",
	"amountWithdrawPercentBelow25" => "小额提现25",
	"amountWithdrawPercentBelow50" => "中额提现50",
	"numWithdrawPercentAbove80" => "账户撤资80计数",
	"numWithdrawPercentAbove95" => "账户撤资清退计数",
	"numWithdrawPercentBelow10" => "小额提现10计数",
	"numWithdrawPercentBelow25" => "小额提现25计数",
	"numWithdrawPercentBelow50" => "中额提现50计数",
	"balanceSupplierMean" => "供应余额均值",
	"balanceSupplierMiddle" => "供应余额中位数",
	"balanceSupplierPercent20" => "供应余额20",
	"balanceSupplierPercent40" => "供应余额40",
	"balanceSupplierPercent60" => "供应余额60",
	"balanceSupplierPercent80" => "供应余额80",
	"balanceSupplierPercent95" => "供应余额95",
	"balanceSupplierStd" => "供应余额标准差",
	"numTotalActive" => "活跃账户数",
	"numTotalRows" => "交易条数",
	"percentBiasReference" => "参考偏移值",
	"percentNumNew" => "新户比例",
	"percentNumReceiving" => "收款比例",
	"percentNumSending" => "发送比例",
	"timestamp" => "时间",
)

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
function plotfit(v::Vector, rng::UnitRange, baseY)::Vector
	v = deepcopy(v) .+ 0.00
	s = sort(v)
	vMin, vMax = s[1], s[end]
	vBias = vMax - vMin
	v .-= vMin
	v ./= vBias / (rng[end] - rng[1])
	v .+= rng[1]
	s = sort(v)
	v .+= baseY - (s[end]+s[1])/2
	return v
	end
function tobias(v::Vector, rng::UnitRange=-100:100, baseY::Int=0)::Vector
	v = deepcopy(v) .+ 0.00
	tmpMid = sort(v)[ceil(Int,length(v)/2)]
	tmpRet = (v .- tmpMid) ./ tmpMid
	plotfit(tmpRet, rng, baseY)
	end


translateDict["大户提现"] = "大户提现"
function furtherCalculate!(d::Dict)::Dict
	d["results"]["大户提现"] = d["results"]["amountSupplierBalanceAbove95"] - d["results"]["amountWithdrawPercentAbove95"]
	return d
	end


singleHeight = 100
function GetData(num::Int=5, intervalSecs::Int=7200)::Dict
	tmpUrl = serviceURL*"?session=$(GenerateScript())&num=$num&interval=$intervalSecs"
	d = String(HTTP.get(tmpUrl).body) |> JSON.Parser.parse
	return d
	end
function GetView(d::Dict)
	tmpRet = d["results"]
	listTs = tmpRet["timestamp"]
	baseList = tmpRet["amountTotalTransfer"]
	delete!(tmpRet, "timestamp")
	delete!(tmpRet, "amountTotalTransfer")
	tmpKeys = tmpRet |> keys |> collect |> sort
	traces = GenericTrace[]
	for s in tmpKeys
		tmpList  = tmpRet[s] #./ baseList
		tmpList  = plotfit(tmpList, -singleHeight:singleHeight, 0)
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
	delete!(tmpRet, "timestamp")
	delete!(tmpRet, "amountTotalTransfer")
	tmpRet = d["results"]
	listTs = tmpRet["timestamp"]
	tmpKeys = tmpRet |> keys |> collect |> sort
	traces = GenericTrace[]
	for s in tmpKeys
		tmpList  = tmpRet[s] ./ baseList
		tmpList  = plotfit(tmpList, -singleHeight:singleHeight, 0)
		push!(traces, 
			PlotlyJS.scatter(
				x = listTs,
				y = tmpList,
				name = translateDict[s],
				mode = "markers",
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

simpList = String[
	# 止盈止损
	"amountRealizedLossBillion", "amountRealizedProfitBillion",
	# 资金动向
	"amountContinuousD1Buying", "amountContinuousD1Sending",
	"amountContinuousD3Buying", "amountContinuousD3Sending",
	"amountContinuousW1Buying", "amountContinuousW1Sending",
	# 老户唤醒
	"amountWakeupD1Buying", "amountWakeupD1Sending",
	# 新户情况
	"amountChargePercentEquals100", "balanceSupplierMean",
	# 时间加权
	"numBuyerMomentum", "numSupplierMomentum",
	# 老户情况
	"amountBuyerBalanceAbove95", "amountSupplierBalanceAbove95",
	]
function SimpView(numDays::Int=3, intervalSecs::Int=7200)
	d = GetData(numDays, intervalSecs)
	tmpRet = d["results"]
	listTs = map(
		x-> string( unix2datetime(x) + Hour(8) ),
		tmpRet["timestamp"]
		)
	listTs = map(
		x-> x[end-10:end-9] * "-" * x[end-7:end-3],
		listTs
		)
	baseList = tmpRet["amountTotalTransfer"]
	tmpKeys = simpList
	traces = GenericTrace[]
	tmpBaseY = 0
	for i in 1:length(tmpKeys)
		s = tmpKeys[i]
		tmpList = tmpRet[s]
		tmpList = plotfit(tmpList, -100:100, tmpBaseY)
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
	prices = plotfit(d["prices"], 0:tmpBaseY, tmpBaseY/2)
	push!(traces, 
		PlotlyJS.scatter(x = listTs, y = prices,
			name = "实际值", marker_color = "black", yaxis = "实际值")
	)
	PlotlyJS.plot(
		traces,
		Layout(
			title_text = listTs[end] * " $(d["latestH"]) $(d["latestL"])",
			xaxis_title_text = "时间",
		)
	)
	end
