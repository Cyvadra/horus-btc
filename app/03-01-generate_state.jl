
# Deps check
	ProgressMeter
	FinanceDB
	pairName = "BTC_USDT"

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
	# relevant usdt amount
	UsdtPayed4Input::Float64
	UsdtReceived4Output::Float64
	AveragePurchasePrice::Float32
	LastSellPrice::Float32
	# calculated extra
	UsdtNetRealized::Float64
	UsdtNetUnrealized::Float64
	Balance::Float64
	end
function GenerateState(addrId::UInt32, startN::Int, endN::Int)::AddressStatistics
	mintTags  = map(x->x>0.0, sumAmount[startN:endN])
	spentTags = map(x->x<0.0, sumAmount[startN:endN])
	# collect index
		tmpInds   = collect(startN:endN)
		mintInds  = tmpInds[mintTags]
		spentInds = tmpInds[spentTags]
	ret   = AddressStatistics(
		min(sumTs[startN:endN]...), # TimestampCreated Int32
		max(sumTs[startN:endN]...), # TimestampLastActive Int32
		sumTs[mintInds[end]], # TimestampLastReceived Int32
		sumTs[spentInds[end]], # TimestampLastPayed Int32
		sumAmount[mintInds] |> sum, # AmountIncomeTotal Float64
		sumAmount[spentInds] |> sum |> abs, # AmountExpenseTotal Float64
		sum(mintTags), # NumTxInTotal Int32
		sum(spentTags), # NumTxOutTotal Int32
		0, # UsdtPayed4Input Float64
		0, # UsdtReceived4Output Float64
		0, # AveragePurchasePrice Float32
		FinanceDB.GetDerivativePriceWhen(pairName, sumTs[spentInds[end]]), # LastSellPrice Float32
		0, # UsdtNetRealized Float64
		0, # UsdtNetUnrealized Float64
		0 , # Balance Float64
	)
	# default value
		# firstPrice   = FinanceDB.GetDerivativePriceWhen(pairName, BlockNum2Timestamp(mintNums[1]))
		currentPrice = FinanceDB.GetDerivativePriceWhen(pairName, max(sumTs[startN:endN]...))
	# Balance
		ret.Balance = ret.AmountIncomeTotal - ret.AmountExpenseTotal
	# Usdt
		ret.UsdtPayed4Input = [ sumAmount[i] * FinanceDB.GetDerivativePriceWhen(pairName, sumTs[i]) for i in mintInds ] |> sum
		ret.UsdtReceived4Output = [ sumAmount[i] * FinanceDB.GetDerivativePriceWhen(pairName, sumTs[i]) for i in spentInds ] |> sum |> abs
		if ret.AmountIncomeTotal > 1e9
			ret.AveragePurchasePrice = ret.UsdtPayed4Input / ret.AmountIncomeTotal
		else
			ret.AveragePurchasePrice = currentPrice
		end
	# UsdtNetRealized / UsdtNetUnrealized
		ret.UsdtNetRealized = ret.UsdtReceived4Output - ret.UsdtPayed4Input
		ret.UsdtNetUnrealized = ret.Balance * (currentPrice - ret.AveragePurchasePrice)
	return ret
	end






nextPosRef = 1
currentPos = 1
addrId = sumAddrId[currentPos]
endPos = findnext(x->x!==addrId, sumAddrId, nextPosRef) - 1

prog = ProgressMeter.Progress(length(sumTs); barlen=36, color=:blue)
while !isnothing(endPos)
	txs    = currentPos:endPos
	# ...
	next!(prog, length(txs))
	currentPos = endPos + 1
	addrId = sumAddrId[currentPos]
	endPos = findnext(x->x!==addrId, sumAddrId, nextPosRef) - 1
	end






