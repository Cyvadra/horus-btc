
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
	"amountWakeupD1Buying" => "休眠买入D1",
	"amountWakeupD1Sending" => "休眠卖出D1",
	"amountWakeupD3Buying" => "休眠买入D3",
	"amountWakeupD3Sending" => "休眠卖出D3",
	"numWakeupD1Buying" => "休眠买入D1计数",
	"numWakeupD1Sending" => "休眠卖出D1计数",
	"numWakeupD3Buying" => "休眠买入D3计数",
	"numWakeupD3Sending" => "休眠卖出D3计数",
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
	"balanceBuyerMean" => "买家余额均值",
	"balanceBuyerStd" => "买家余额方差",
	"balanceBuyerPercent20" => "买家余额20",
	"balanceBuyerPercent40" => "买家余额40",
	"balanceBuyerMiddle" => "买家余额50",
	"balanceBuyerPercent60" => "买家余额60",
	"balanceBuyerPercent80" => "买家余额80",
	"balanceBuyerPercent95" => "买家余额95",
	"amountBuyerBalanceBelow20" => "散户买入20",
	"amountBuyerBalanceBelow40" => "散户买入40",
	"amountBuyerBalanceBelow60" => "散户买入60",
	"amountBuyerBalanceBelow80" => "中户买入80",
	"amountBuyerBalanceAbove80" => "大户买入80",
	"amountBuyerBalanceAbove95" => "大户买入90",
	"balanceSupplierStd" => "供应余额标准差",
	"numSupplierMomentum" => "供应动量",
	"numSupplierMomentumMean" => "供应动量均值",
	"numBuyerMomentum" => "买家动量",
	"numBuyerMomentumMean" => "买家动量均值",
	"numRegularBuyerMomentum" => "老客动量",
	"numRegularBuyerMomentumMean" => "老客动量均值",
	"numTotalActive" => "活跃账户数",
	"numTotalRows" => "交易条数",
	"percentBiasReference" => "参考偏移值",
	"percentNumNew" => "新户比例",
	"percentNumReceiving" => "收款比例",
	"percentNumSending" => "发送比例",
	"timestamp" => "时间",
	)

simpList = String[
	# 止盈止损
	"amountRealizedLossBillion", "amountRealizedProfitBillion",
	# 资金动向
	"amountContinuousD1Buying", "amountContinuousD1Sending",
	"amountContinuousD3Buying", "amountContinuousD3Sending",
	"amountContinuousW1Buying", "amountContinuousW1Sending",
	# 新户情况
	"amountChargePercentEquals100", "balanceSupplierMean",
	# 老户情况
	"amountChargePercentBelow10", "amountSupplierBalanceAbove95",
	]

dnnListTest = String[
	"amountRealizedLossBillion",
	"amountRealizedProfitBillion",
	"amountChargePercentEquals100",
	"amountContinuousD1Buying",
	"amountContinuousD1Sending",
	"amountContinuousD3Buying",
	"amountContinuousD3Sending",
	"amountContinuousW1Buying",
	"amountContinuousW1Sending",
	]

dnnListLab = String[
	"amountBuyerBalanceBelow60",
	"amountBuyerBalanceBelow80",
	"amountChargePercentBelow25",
	"amountChargePercentBelow50",
	"amountChargePercentBelow80",
	"amountChargePercentBelow95",
	"amountContinuousD1Buying",
	"amountContinuousD3Buying",
	"amountRealizedLossBillion",
	"amountRealizedProfitBillion",
	"amountSupplierBalanceAbove95",
	"amountSupplierBalanceBelow40",
	"amountSupplierBalanceBelow60",
	"amountWithdrawPercentAbove80",
	"amountWithdrawPercentAbove95",
	"numChargePercentBelow10",
	"numChargePercentBelow25",
	"numChargePercentBelow50",
	"numChargePercentBelow95",
	"numChargePercentEquals100",
	"numContinuousD1Buying",
	"numContinuousD1Sending",
	"numContinuousD3Sending",
	"numRealizedProfit",
	"numRecentD3Buying",
	"numRecentD3Sending",
	"numSupplierMomentum",
	"numTotalActive",
	"numWithdrawPercentAbove80",
	"numWithdrawPercentBelow25",
	"numWithdrawPercentBelow50"
	]

dnnList = String[
	"amountChargePercentBelow10",
	"amountChargePercentBelow25",
	"amountChargePercentBelow50",
	"amountChargePercentBelow80",
	"amountChargePercentBelow95",
	"amountChargePercentEquals100",
	"numChargePercentBelow10",
	"numChargePercentBelow25",
	"numChargePercentBelow50",
	"numChargePercentBelow80",
	"numChargePercentBelow95",
	"numChargePercentEquals100",
	"amountContinuousD1Buying",
	"amountContinuousD1Sending",
	"amountContinuousD3Buying",
	"amountContinuousD3Sending",
	"amountContinuousW1Buying",
	"amountContinuousW1Sending",
	"numContinuousD1Buying",
	"numContinuousD1Sending",
	"numContinuousD3Buying",
	"numContinuousD3Sending",
	"numContinuousW1Buying",
	"numContinuousW1Sending",
	"amountRealizedLossBillion",
	"amountRealizedProfitBillion",
	"amountRecentD3Buying",
	"amountRecentD3Sending",
	"numRealizedLoss",
	"numRealizedProfit",
	"numRecentD3Buying",
	"numRecentD3Sending",
	"amountSupplierBalanceAbove95",
	"amountSupplierBalanceBelow20",
	"amountSupplierBalanceBelow40",
	"amountSupplierBalanceBelow60",
	"amountSupplierBalanceBelow80",
	"amountTotalTransfer",
	"amountWithdrawPercentAbove80",
	"amountWithdrawPercentAbove95",
	"amountWithdrawPercentBelow10",
	"amountWithdrawPercentBelow25",
	"amountWithdrawPercentBelow50",
	"numWithdrawPercentAbove80",
	"numWithdrawPercentAbove95",
	"numWithdrawPercentBelow10",
	"numWithdrawPercentBelow25",
	"numWithdrawPercentBelow50",
	"balanceSupplierMean",
	"balanceSupplierStd",
	# "balanceSupplierMiddle",
	# "balanceSupplierPercent20",
	# "balanceSupplierPercent40",
	# "balanceSupplierPercent60",
	# "balanceSupplierPercent80",
	"balanceSupplierPercent95",
	"balanceBuyerMean",
	"balanceBuyerStd",
	# "balanceBuyerPercent20",
	# "balanceBuyerPercent40",
	# "balanceBuyerMiddle",
	# "balanceBuyerPercent60",
	# "balanceBuyerPercent80",
	"balanceBuyerPercent95",
	"amountBuyerBalanceBelow20",
	"amountBuyerBalanceBelow40",
	"amountBuyerBalanceBelow60",
	"amountBuyerBalanceBelow80",
	"amountBuyerBalanceAbove80",
	"amountBuyerBalanceAbove95",
	"numSupplierMomentum",
	# "numSupplierMomentumMean",
	"numBuyerMomentum",
	# "numBuyerMomentumMean",
	"numRegularBuyerMomentum",
	# "numRegularBuyerMomentumMean",
	"numTotalActive",
	"numTotalRows",
	"percentNumNew",
	"percentNumReceiving",
	"percentNumSending",
	"amountTotalTransfer",
] |> sort

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
	v = replace(v, nothing=>0.0) .+ 0.0
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

function plotfit_multi(lv::Vector{Vector{T}}, rng::UnitRange, baseY)::Vector{Vector{T}} where T <: Real
	[ lv[i] = replace(lv[i], nothing=>0.0) .+ 0.0 for i in 1:length(lv) ]
	vMin = min( map(x->min(x...), lv)... )
	vMax = max( map(x->max(x...), lv)... )
	vBias= (vMax - vMin) / (rng[end] - rng[1])
	vMin = vMin / vBias
	for i in 1:length(lv)
		lv[i] ./= vBias
		lv[i] .-= vMin
		lv[i] .+= rng[1]
	end
	return lv
	end

function plotfit_ma(v::Vector, rng::UnitRange, baseY, numMa)::Vector
	v = replace(v, nothing=>0.0) .+ 0.0
	vRet = deepcopy(v)
	tmpMin = min(v[1:numMa]...)
	tmpMax = max(v[1:numMa]...)
	tmpBias = tmpMax - tmpMin
	for i in 1:numMa
		vRet[i] = (v[i] - tmpMin) / tmpBias # + rng[1] + baseY - original_mid
	end
	tmpWeight = ceil(Int, numMa/12)
	for i in numMa+1:length(v)-numMa
		tmpMin = (min(v[i-numMa:i+numMa]...) + tmpWeight*tmpMin) / (tmpWeight+1)
		tmpMax = (max(v[i-numMa:i+numMa]...) + tmpWeight*tmpMax) / (tmpWeight+1)
		tmpBias = tmpMax - tmpMin
		vRet[i] = (v[i] - tmpMin) / tmpBias
	end
	for i in length(v)-numMa+1:length(v)
		vRet[i] = (v[i] - tmpMin) / tmpBias
	end
	vRet .*= rng[end] - rng[1]
	vRet .+= rng[1]
	vRet .+= baseY - Statistics.mean(vRet)
	return vRet
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

priceRange = 10000:100000
