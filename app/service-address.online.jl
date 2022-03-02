
# Realtime Address Service
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
mutable struct AddressDiff
	# timestamp
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
	LastSellPrice::Float32
	end
tplAddressDiff       = AddressDiff(zeros(length(AddressDiff.types))...)
tplAddressStatistics = AddressStatistics(zeros(length(AddressStatistics.types))...)
function Address2State(addr::String, blockNum::Int)::AddressStatistics
	# (1, blockNum]
	blockNum += 1
	coins = Mongoc.find(
		MongoCollection("coins"),
		Mongoc.BSON(
			"""{
				"address":"$addr",
				"mintHeight": {"\$lt":$blockNum, "\$gt":0}
			}"""
		)
	) |> collect
	blockNum -= 1
	mintRange = map(x->0 < x["mintHeight"], coins)
	spentRange= map(x->0 < x["spentHeight"] <= blockNum, coins)
	mintNums  = map(x->x["mintHeight"], coins[mintRange])
	spentNums = map(x->x["spentHeight"], coins[spentRange])
	blockNums = sort!(vcat(mintNums, spentNums))
	# check
		if length(mintNums) == 0
			@warn "no transaction found at address: $addr"
			return deepcopy(tplAddressStatistics)
		end
	ret   = AddressStatistics(
		blockNums[1] |> BlockNum2Timestamp, # TimestampCreated Int32
		blockNums[end] |> BlockNum2Timestamp, # TimestampLastActive Int32
		mintNums[end] |> BlockNum2Timestamp, # TimestampLastReceived Int32
		0, # TimestampLastPayed Int32
		map(x->x["value"],
			coins[mintRange]
		) |> sum |> bitcoreInt2Float64, # AmountIncomeTotal Float64
		0, # AmountExpenseTotal Float64
		length(mintNums), # NumTxInTotal Int32
		length(spentNums), # NumTxOutTotal Int32
		0, # UsdtPayed4Input Float64
		0, # UsdtReceived4Output Float64
		0, # AveragePurchasePrice Float32
		0, # LastSellPrice Float32
		0, # UsdtNetRealized Float64
		0, # UsdtNetUnrealized Float64
		0 , # Balance Float64
	)
	# default value
		firstPrice   = FinanceDB.GetDerivativePriceWhen(pairName, BlockNum2Timestamp(mintNums[1]))
		currentPrice = FinanceDB.GetDerivativePriceWhen(pairName, BlockNum2Timestamp(blockNum))
	# Balance
		ret.Balance = ret.AmountIncomeTotal - ret.AmountExpenseTotal
	# Spent coins
		if length(spentNums) > 0
			ret.LastSellPrice = FinanceDB.GetDerivativePriceWhen( pairName, BlockNum2Timestamp(spentNums[end]) )
			ret.TimestampLastPayed = spentNums[end] |> BlockNum2Timestamp
			ret.AmountExpenseTotal = map(
				x->x["value"],
				coins[spentRange]
			) |> sum |> bitcoreInt2Float64
		else
			ret.LastSellPrice = firstPrice
		end
	# Usdt
		ret.UsdtPayed4Input = map(
			x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["mintHeight"]),
			coins[mintRange]
		) |> sum
		ret.UsdtReceived4Output = map(
			x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["spentHeight"]),
			coins[spentRange]
		) |> sum
		if ret.Balance > 0.00
			ret.AveragePurchasePrice = ret.UsdtPayed4Input / ret.AmountIncomeTotal
		else
			ret.AveragePurchasePrice = firstPrice
		end
	# UsdtNetRealized / UsdtNetUnrealized
		ret.UsdtNetRealized = ret.UsdtReceived4Output - ret.UsdtPayed4Input
		ret.UsdtNetUnrealized = ret.Balance * (currentPrice - ret.AveragePurchasePrice)
	return ret
	end
function Address2StateDiff(addr::String, fromBlock::Int, toBlock::Int)::AddressDiff
	# [fromBlock, toBlock]
	fromBlock -= 1
	toBlock   += 1
	coins = Mongoc.find(
		MongoCollection("coins"),
		Mongoc.BSON(
			"""{
				"address":"$addr",
				"mintHeight": {"\$lt":$toBlock, "\$gt":$fromBlock}
			}"""
		)
	) |> collect
	fromBlock += 1
	toBlock   -= 1
	spentRange= map(x->0 < x["spentHeight"] <= toBlock, coins)
	mintNums  = map(x->x["mintHeight"], coins)
	spentNums = map(x->x["spentHeight"], coins[spentRange])
	blockNums = sort!(vcat(mintNums, spentNums))
	ret       = deepcopy(tplAddressDiff)
	if length(blockNums) > 0
		if length(mintNums) > 0
			ret.TimestampLastReceived = mintNums[end] |> BlockNum2Timestamp
			ret.AmountIncomeTotal = map(
				x->x["value"],
				coins
			) |> sum |> bitcoreInt2Float64
			ret.NumTxInTotal = length(mintNums)
		end
		if length(spentNums) > 0
			ret.TimestampLastPayed = spentNums[end] |> BlockNum2Timestamp
			ret.AmountExpenseTotal = map(
				x->x["value"],
				coins[spentRange]
			) |> sum |> bitcoreInt2Float64
			ret.NumTxOutTotal = length(spentNums)
		end
	end
	# LastSellPrice
		if length(spentNums) > 0
			ret.LastSellPrice = FinanceDB.GetDerivativePriceWhen( pairName, BlockNum2Timestamp(spentNums[end]) )
		end
	# Usdt
		if length(mintNums) > 0
			ret.UsdtPayed4Input = map(
				x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["mintHeight"]),
				coins
			) |> sum
		end
		if length(spentNums) > 0
			ret.UsdtReceived4Output = map(
				x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["spentHeight"]),
				coins[spentRange]
			) |> sum
		end
	return ret
	end
function MergeAddressState!(baseState::AddressStatistics, arrayDiff::Vector{AddressDiff}, coinPrice::Float32)::AddressStatistics
	for d in arrayDiff
		if d.TimestampLastReceived > 0
			baseState.TimestampLastReceived = d.TimestampLastReceived
			baseState.AmountIncomeTotal += d.AmountIncomeTotal
			baseState.NumTxInTotal += d.NumTxInTotal
			baseState.UsdtPayed4Input += d.UsdtPayed4Input
			if iszero(baseState.TimestampCreated)
				baseState.TimestampCreated = d.TimestampLastReceived
			end
		end
		if d.TimestampLastPayed > 0
			baseState.TimestampLastPayed = d.TimestampLastPayed
			baseState.AmountExpenseTotal += d.AmountExpenseTotal
			baseState.NumTxOutTotal += d.NumTxOutTotal
			baseState.UsdtReceived4Output += d.UsdtReceived4Output
			baseState.LastSellPrice = d.LastSellPrice
		end
	end
	baseState.TimestampLastActive = max(baseState.TimestampLastReceived, baseState.TimestampLastPayed)
	baseState.AveragePurchasePrice = baseState.UsdtPayed4Input / baseState.AmountIncomeTotal
	baseState.UsdtNetRealized = baseState.UsdtReceived4Output - baseState.UsdtPayed4Input
	baseState.Balance = baseState.AmountIncomeTotal - baseState.AmountExpenseTotal
	baseState.UsdtNetUnrealized = baseState.Balance * (coinPrice - ret.AveragePurchasePrice)
	return baseState
	end
function MergeAddressState(baseState::AddressStatistics, arrayDiff::Vector{AddressDiff}, coinPrice::Float32)::AddressStatistics
	baseState = deepcopy(baseState)
	for d in arrayDiff
		if d.TimestampLastReceived > 0
			baseState.TimestampLastReceived = d.TimestampLastReceived
			baseState.AmountIncomeTotal += d.AmountIncomeTotal
			baseState.NumTxInTotal += d.NumTxInTotal
			baseState.UsdtPayed4Input += d.UsdtPayed4Input
			if iszero(baseState.TimestampCreated)
				baseState.TimestampCreated = d.TimestampLastReceived
			end
		end
		if d.TimestampLastPayed > 0
			baseState.TimestampLastPayed = d.TimestampLastPayed
			baseState.AmountExpenseTotal += d.AmountExpenseTotal
			baseState.NumTxOutTotal += d.NumTxOutTotal
			baseState.UsdtReceived4Output += d.UsdtReceived4Output
			baseState.LastSellPrice = d.LastSellPrice
		end
	end
	baseState.TimestampLastActive = max(baseState.TimestampLastReceived, baseState.TimestampLastPayed)
	baseState.AveragePurchasePrice = baseState.UsdtPayed4Input / baseState.AmountIncomeTotal
	baseState.UsdtNetRealized = baseState.UsdtReceived4Output - baseState.UsdtPayed4Input
	baseState.Balance = baseState.AmountIncomeTotal - baseState.AmountExpenseTotal
	baseState.UsdtNetUnrealized = baseState.Balance * (coinPrice - ret.AveragePurchasePrice)
	return baseState
	end


addrCacheFolder = "/media/jason89757/gloway/addrCache/"

mutable struct AddressCache
	blockHeight::Int32
	baseState::AddressStatistics
	end
AddressCacheDict = Dict{UInt32, AddressCache}()
function LoadAddressCache()::Nothing
	for f in readdir(addrCacheFolder)
		addrId = String2IDSafe(string(f[1:end-4]))
		AddressCacheDict[addrId] = JLD2.load(addrCacheFolder*f)["cache"]
	end
	return nothing
	end

