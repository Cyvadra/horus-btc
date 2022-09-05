
# Deps check
	using ProgressMeter
	using JLD2, DataFrames
	using SoftGlobalScope
	using ThreadsX
	dataFolder = "/mnt/data/bitcore/"

# load modules
	include("./service-address.jl")
	include("./service-FinanceDB.jl")
# load calculation data
	res = JLD2.load(dataFolder*"TxRows.sorted.vector.jld2");
	sumAddrId = res["sumAddrId"]
	sumAmount = res["sumAmount"]
	sumTs     = res["sumTs"]
	res = nothing
# load cache data
	res = JLD2.load(dataFolder*"listPositionsForParallel.jld2");
	listStartPos = res["listStartPos"]
	listEndPos = res["listEndPos"]
	listAddrId = res["listAddrId"]
	res = nothing


mutable struct AddressStatistics
	# timestamp
	TimestampCreated::Int32
	TimestampLastActive::Int32
	TimestampLastReceived::Int32
	TimestampLastPayed::Int32
	# amount
	AmountIncomeTotal::Float64
	AmountExpenseTotal::Float64
	# statistics
	NumTxInTotal::Int32
	NumTxOutTotal::Int32
	NumTxTotal::Int32
	AverageTradeIntervalSecs::Int32
	# relevant usdt amount
	UsdtPayed4Input::Float64
	UsdtReceived4Output::Float64
	AveragePurchasePrice::Float32
	LastPurchasePrice::Float32
	LastSellPrice::Float32
	# calculated extra
	UsdtNetRealized::Float64
	UsdtNetUnrealized::Float64
	NumWinning::Int32
	NumLossing::Int32
	UsdtAmountWon::Float64
	UsdtAmountLost::Float64
	RateWinning::Float32
	# basic
	Balance::Float64
	end
function GenerateState(startN::Int, endN::Int)::AddressStatistics
	mintTags  = map(x->x>0.0, sumAmount[startN:endN])
	spentTags = map(x->x<0.0, sumAmount[startN:endN])
	# collect index
		tmpInds   = collect(startN:endN)
		mintInds  = tmpInds[mintTags]
		spentInds = tmpInds[spentTags]
	ret   = AddressStatistics(
		min(sumTs[startN:endN]...), # TimestampCreated Int32
		max(sumTs[startN:endN]...), # TimestampLastActive Int32
		sumTs[end], # TimestampLastReceived Int32
		sumTs[1], # TimestampLastPayed Int32
		0, # AmountIncomeTotal Float64
		0, # AmountExpenseTotal Float64
		0, # NumTxInTotal Int32
		0, # NumTxOutTotal Int32
		0, # NumTxTotal Int32
		0, # AverageTradeIntervalSecs Int32
		0, # UsdtPayed4Input Float64
		0, # UsdtReceived4Output Float64
		0, # AveragePurchasePrice Float32
		0, # LastPurchasePrice Float32
		0, # LastSellPrice Float32
		0, # UsdtNetRealized Float64
		0, # UsdtNetUnrealized Float64
		0, # NumWinning Int32
		0, # NumLossing Int32
		0, # UsdtAmountWon Float64
		0, # UsdtAmountLost Float64
		0, # RateWinning Float32
		0 , # Balance Float64
	)
	# general mint
		if length(mintInds) > 0
			ret.TimestampLastReceived = sumTs[mintInds[end]]
			ret.AmountIncomeTotal = sumAmount[mintInds] |> sum
			ret.UsdtPayed4Input = [ sumAmount[i] * GetBTCPriceWhen(sumTs[i]) for i in mintInds ] |> sum
			ret.NumTxInTotal = sum(mintTags)
		end
	# default value
		# firstPrice   = GetBTCPriceWhen(pairName, BlockNum2Timestamp(mintNums[1]))
		currentPrice = GetBTCPriceWhen(max(sumTs[startN:endN]...))
	# Balance
		ret.Balance = ret.AmountIncomeTotal - ret.AmountExpenseTotal
	# Usdt
		if ret.AmountIncomeTotal > 1e9
			ret.AveragePurchasePrice = ret.UsdtPayed4Input / ret.AmountIncomeTotal
		else
			ret.AveragePurchasePrice = currentPrice
		end
	# Conditional: 
	# TimestampLastPayed, LastSellPrice, UsdtReceived4Output
		if length(spentInds) > 0
			ret.NumTxOutTotal = sum(spentTags)
			ret.TimestampLastPayed = length(spentInds) > 0 ? sumTs[spentInds[end]] : sumTs[1]
			ret.AmountExpenseTotal = sumAmount[spentInds] |> sum |> abs
			ret.LastSellPrice = GetBTCPriceWhen(sumTs[spentInds[end]])
			ret.UsdtReceived4Output = [ sumAmount[i] * GetBTCPriceWhen(sumTs[i]) for i in spentInds ] |> sum |> abs
		else
			ret.LastSellPrice = GetBTCPriceWhen(sumTs[end])
		end
	# UsdtNetRealized / UsdtNetUnrealized
		ret.UsdtNetRealized = ret.UsdtReceived4Output - ret.UsdtPayed4Input
		ret.UsdtNetUnrealized = ret.Balance * (currentPrice - ret.AveragePurchasePrice)
	return ret
	end

# pretreatment
if false
	include("./03-01-01-pretreatment.jl")
end

# Calculation: listXXX ==> Vector{AddressStatistics} ==> memory cache
AddressService.CreateMem(round(Int,1.1e9))
_len = length(listAddrId)
# echo 3 > /proc/sys/vm/drop_caches
prog = ProgressMeter.Progress(_len; barlen=32)
GC.safepoint()
Threads.@threads for i in _len:-1:1
	try
	AddressService.SetRow(
		listAddrId[i],
		GenerateState(
			listStartPos[i],
			listEndPos[i]
		)
	)
	catch e
		println()
		@warn e
		@warn i
		println()
		break
	end
	next!(prog)
end








# len_data   = length(sumAddrId) - 20000 # waiting FinanceDB
# listStartPos = Int[]
# listEndPos = Int[]
# listAddrId = UInt32[]
# currentPos = 1
# nextPosRef = 1
# tmpAddrId  = sumAddrId[1]
# prog = Progress(len_data)
# @softscope while true
# 	nextPosRef = findnext(x->x!==tmpAddrId, sumAddrId, nextPosRef)
# 	if isnothing(nextPosRef)
# 		break
# 	end
# 	push!(listStartPos, currentPos)
# 	push!(listEndPos, nextPosRef - 1)
# 	push!(listAddrId, tmpAddrId)
# 	currentPos    = nextPosRef
# 	nextPosRef    = currentPos + 1
# 	tmpAddrId     = sumAddrId[currentPos]
# 	next!(prog)
# end


