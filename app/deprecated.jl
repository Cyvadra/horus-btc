
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



	function batchTouch!(rng::UnitRange{Int})::Nothing
		coinPrice = FinanceDB.GetDerivativePriceWhen.(pairName, sumTs[rng[end]])
		# existing addresses
		concreteIndexes = rng[map(x->!x, sumTagNew[rng])]
		uniqueAddrIds   = unique(sumAddrId[concreteIndexes])
		tmpAmountIncomeDict  = Dict{UInt32, Float64}()
		tmpAmountExpenseDict = Dict{UInt32, Float64}()
		tmpTsInDict   = Dict{UInt32, Vector{Int32}}()
		tmpTsOutDict  = Dict{UInt32, Vector{Int32}}()
		for addrId in uniqueAddrIds
			tmpRng = findall(x->x==addrId, sumAddrId[concreteIndexes])
			tmpAmounts = sumAmount[concreteIndexes][tmpRng]
			tmpAmountIncomeDict[addrId]  = sum(tmpAmounts[tmpAmounts .> 0.0])
			tmpAmountExpenseDict[addrId] = sum(tmpAmounts[tmpAmounts .< 0.0])
			tmpTsInDict[addrId]  = sumTs[concreteIndexes][tmpRng][sumAmount[concreteIndexes][tmpRng] .> 0]
			tmpTsOutDict[addrId] = sumTs[concreteIndexes][tmpRng][sumAmount[concreteIndexes][tmpRng] .< 0]
		end
		for addrId in uniqueAddrIds
			tmpBalance = AddressService.GetFieldBalance(addrId)
			if tmpAmountExpenseDict[addrId] > 0
				AddressService.SetFieldDiffAmountExpenseTotal(pos, -tmpAmountExpenseDict[addrId])
				AddressService.SetFieldDiffNumTxOutTotal(pos, length(tmpTsOutDict[addrId]))
				AddressService.SetFieldTimestampLastPayed(pos, tmpTsOutDict[addrId][end])
				tmpPrice = FinanceDB.GetDerivativePriceWhen.( pairName,
						round(Int32, mean(tmpTsOutDict[addrId])) )
				AddressService.SetFieldDiffUsdtReceived4Output(pos, -tmpAmountExpenseDict[addrId] * tmpPrice)
				AddressService.SetFieldLastSellPrice(pos, tmpPrice)
			end
			if tmpAmountIncomeDict[addrId] > 0
				AddressService.SetFieldDiffAmountIncomeTotal(pos, tmpAmountIncomeDict[addrId])
				AddressService.SetFieldDiffNumTxInTotal(pos, length(tmpTsInDict[addrId]))
				AddressService.SetFieldTimestampLastReceived(pos, tmpTsInDict[addrId][end])
				tmpPrice = FinanceDB.GetDerivativePriceWhen.( pairName,
						round(Int32, mean(tmpTsInDict[addrId])) )
				AddressService.SetFieldDiffUsdtPayed4Input(pos, tmpAmountIncomeDict[addrId] * tmpPrice)
				if tmpBalance > 1e-9
					AddressService.SetFieldAveragePurchasePrice(pos,
						(tmpAmountIncomeDict[addrId] * tmpPrice + AddressService.GetFieldAveragePurchasePrice(pos) * tmpBalance) / (tmpBalance + tmpAmountIncomeDict[addrId]) )
				else
					AddressService.SetFieldAveragePurchasePrice(pos, tmpPrice)
				end
			end
			tsList = sort!(vcat(tmpTsInDict[addrId], tmpTsOutDict[addrId]))
			if tmpBalance < 0 && AddressService.GetFieldTimestampCreated(pos) > tsList[1]
				AddressService.SetFieldTimestampCreated(pos, tsList[1])
			end
			if AddressService.GetFieldTimestampLastActive(pos) < tsList[end]
				AddressService.SetFieldTimestampLastActive(pos, tsList[end])
			end
			AddressService.SetFieldDiffBalance(pos, tmpAmountIncomeDict[addrId]+tmpAmountExpenseDict[addrId])
			AddressService.SetFieldUsdtNetRealized(pos,
				 AddressService.GetFieldUsdtReceived4Output(pos) - AddressService.GetFieldUsdtPayed4Input(pos)
				 )
			AddressService.SetFieldUsdtNetUnrealized(pos,
				 ( coinPrice - AddressService.GetFieldAveragePurchasePrice(pos) )
				 * AddressService.GetFieldBalance(pos)
				 )
		end
		# new addresses
		newIndexes  = rng[sumTagNew[rng]]
		for _ind in newIndexes
			pos = sumAddrId[_ind]
			if !sumTagNew[_ind]
				throw("program incorrect!")
			end
			coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[_ind])
			coinUsdt  = abs(sumAmount[_ind]) * coinPrice
			if sumAmount[_ind] >= 0
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, sumAmount[_ind])
				AddressService.SetFieldAmountExpenseTotal(pos, 0.0)
				AddressService.SetFieldNumTxInTotal(pos, 1)
				AddressService.SetFieldNumTxOutTotal(pos, 0)
				AddressService.SetFieldUsdtPayed4Input(pos, coinUsdt)
				AddressService.SetFieldUsdtReceived4Output(pos, 0.0)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, 0.0)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			else
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, 0.0)
				AddressService.SetFieldAmountExpenseTotal(pos, abs(sumAmount[_ind]))
				AddressService.SetFieldNumTxInTotal(pos, 0)
				AddressService.SetFieldNumTxOutTotal(pos, 1)
				AddressService.SetFieldUsdtPayed4Input(pos, 0.0)
				AddressService.SetFieldUsdtReceived4Output(pos, coinUsdt)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, coinUsdt)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			end
		end
		return nothing
		end


