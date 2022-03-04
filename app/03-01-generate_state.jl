
# Deps check
	ProgressMeter
	FinanceDB
	pairName = "BTC_USDT"

# Tx convert

	tmpLen    = nrow(TxRowsDF)
	sumAddrId = deepcopy(TxRowsDF[1:tmpLen, :AddressId])
	sumAmount = deepcopy(TxRowsDF[1:tmpLen, :Amount])
	sumTs     = deepcopy(TxRowsDF[1:tmpLen, :Timestamp])



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
		sumTs[mintInds[end]], # TimestampLastReceived Int32
		sumTs[1], # TimestampLastPayed Int32
		sumAmount[mintInds] |> sum, # AmountIncomeTotal Float64
		0, # AmountExpenseTotal Float64
		sum(mintTags), # NumTxInTotal Int32
		sum(spentTags), # NumTxOutTotal Int32
		0, # UsdtPayed4Input Float64
		0, # UsdtReceived4Output Float64
		0, # AveragePurchasePrice Float32
		0, # LastSellPrice Float32
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
		if ret.AmountIncomeTotal > 1e9
			ret.AveragePurchasePrice = ret.UsdtPayed4Input / ret.AmountIncomeTotal
		else
			ret.AveragePurchasePrice = currentPrice
		end
	# Conditional: 
	# TimestampLastPayed, LastSellPrice, UsdtReceived4Output
		if length(spentInds) > 0
			ret.TimestampLastPayed = length(spentInds) > 0 ? sumTs[spentInds[end]] : sumTs[1]
			ret.AmountExpenseTotal = sumAmount[spentInds] |> sum |> abs
			ret.LastSellPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[spentInds[end]])
			ret.UsdtReceived4Output = [ sumAmount[i] * FinanceDB.GetDerivativePriceWhen(pairName, sumTs[i]) for i in spentInds ] |> sum |> abs
		else
			ret.LastSellPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[end])
		end
	# UsdtNetRealized / UsdtNetUnrealized
		ret.UsdtNetRealized = ret.UsdtReceived4Output - ret.UsdtPayed4Input
		ret.UsdtNetUnrealized = ret.Balance * (currentPrice - ret.AveragePurchasePrice)
	return ret
	end




len_data   = length(sumAddrId) - 10000
numParallel= round(Int, 3*Threads.nthreads())
listStartPos = zeros(Int, numParallel)
listEndPos = zeros(Int, numParallel)
listAddrId = zeros(UInt32, numParallel)
currentPos = 1
nextPosRef = 1
tmpAddrId  = sumAddrId[1]
prog = ProgressMeter.Progress(len_data; barlen=32)
@softscope while !isfile("/tmp/JULIA_EMERGENCY_STOP")
	tmpVal = currentPos - 1
	@softscope for i in 1:numParallel
		listStartPos[i] = currentPos
		listEndPos[i] = findnext(x->x!==tmpAddrId, sumAddrId, nextPosRef) - 1
		listAddrId[i] = tmpAddrId
		currentPos    = listEndPos[i] + 1
		nextPosRef    = currentPos + 1
		tmpAddrId     = sumAddrId[currentPos]
	end
	Threads.@threads for i in 1:numParallel
		AddressService.SetRow(
			listAddrId[i],
			GenerateState(
				listStartPos[i],
				listEndPos[i]
			)
		)
	end
	next!(prog; step = listEndPos[end] - tmpVal)
end


for i in _len:-1:1
	state    = GenerateState(currentPos,endPos)
	AddressService.SetRow(counter, state)
	counter += 1
	next!(prog; step = length(endPos - currentPos + 1))
	currentPos = endPos + 1
	nextPosRef = currentPos + 1
	addrId = sumAddrId[currentPos]
	endPos = findnext(x->x!==addrId, sumAddrId, nextPosRef) - 1
	end






