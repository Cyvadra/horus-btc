
using Mongoc

# include("./service-address.jl");
# include("./service-address2id.traditional.jl");
# include("./service-FinanceDB.jl");
# include("./service-mongo.jl");
# include("./service-block_timestamp.jl");

mutable struct AddressDiff
	AddressId::UInt32
	TimestampLastReceived::Int32
	TimestampLastPayed::Int32
	AmountIncomeTotal::Float64
	AmountExpenseTotal::Float64
	NumTxInTotal::Int32
	NumTxOutTotal::Int32
	UsdtPayed4Input::Float64
	UsdtReceived4Output::Float64
	LastSellPrice::Float32
	end
tplAddressDiff = AddressDiff(zeros(length(AddressDiff.types))...)
# deprecated functions for previous version
function Address2StateDiff(fromBlock::Int, toBlock::Int)::Vector{AddressDiff} # (fromBlock, toBlock]
	if fromBlock == toBlock
		return AddressDiff[]
	end
	fromBlock += 1
	ret = Vector{AddressDiff}()
	coinsAll = GetBlockCoinsInRange(fromBlock, toBlock)
	sort!(coinsAll, by=x->x["address"])
	counter = 1
	counterNext = findnext(
		x->x["address"] !== coinsAll[counter]["address"],
		coinsAll,
		counter
	)
	if isnothing(counterNext)
		if length(coinsAll) == 1
			push!(ret, AddressDiff(
				GenerateID(coinsAll[counter]["address"]),
				coinsAll[counter]["mintHeight"] |> BlockNum2Timestamp,
				0,
				coinsAll[counter]["value"] |> bitcoreInt2Float64,
				0,
				1,
				0,
				(coinsAll[counter]["value"] |> bitcoreInt2Float64) * GetBTCPriceWhen(BlockNum2Timestamp(coinsAll[counter]["mintHeight"])),
				0,
				0,
				))
			return ret
		else
			throw("enexpected $toBlock")
		end
	end
	while !isnothing(counterNext)
		counterNext -= 1
		currentDiff = AddressDiff(zeros(length(AddressDiff.types))...)
		currentDiff.AddressId = GenerateID(coinsAll[counter]["address"])
		coins     = coinsAll[counter:counterNext]
		mintRange = map(x->fromBlock <= x["mintHeight"] <= toBlock, coins)
		spentRange= map(x->fromBlock <= x["spentHeight"] <= toBlock, coins)
		mintNums  = map(x->x["mintHeight"], coins[mintRange])
		spentNums = map(x->x["spentHeight"], coins[spentRange])
		blockNums = sort!(vcat(mintNums, spentNums))
		if length(blockNums) > 0
			if length(mintNums) > 0
				currentDiff.TimestampLastReceived = mintNums[end] |> BlockNum2Timestamp
				currentDiff.AmountIncomeTotal = map(
					x->x["value"],
					coins[mintRange]
				) |> sum |> bitcoreInt2Float64
				currentDiff.NumTxInTotal = length(mintNums)
			end
			if length(spentNums) > 0
				currentDiff.TimestampLastPayed = spentNums[end] |> BlockNum2Timestamp
				currentDiff.AmountExpenseTotal = map(
					x->x["value"],
					coins[spentRange]
				) |> sum |> bitcoreInt2Float64
				currentDiff.NumTxOutTotal = length(spentNums)
			end
		end
		# LastSellPrice
			if length(spentNums) > 0
				currentDiff.LastSellPrice = GetBTCPriceWhen(BlockNum2Timestamp(spentNums[end]))
			end
		# Usdt
			if length(mintNums) > 0
				currentDiff.UsdtPayed4Input = map(
					x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["mintHeight"]),
					coins
				) |> sum
			end
			if length(spentNums) > 0
				currentDiff.UsdtReceived4Output = map(
					x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["spentHeight"]),
					coins[spentRange]
				) |> sum
			end
		counter = counterNext + 1
		addr    = coinsAll[counter]["address"]
		counterNext = findnext(
			x->x["address"] !== addr,
			coinsAll,
			counter
		)
		push!(ret, currentDiff)
	end
	return ret
	end
function MergeAddressState!(arrayDiff::Vector{AddressDiff}, coinPrice::Float32)::Int
	counter = 0
	for d in arrayDiff
		baseState = AddressService.GetRow(d.AddressId)
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
		baseState.TimestampLastActive = max(baseState.TimestampLastReceived, baseState.TimestampLastPayed)
		baseState.AveragePurchasePrice = baseState.UsdtPayed4Input / baseState.AmountIncomeTotal
		baseState.UsdtNetRealized = baseState.UsdtReceived4Output - baseState.UsdtPayed4Input
		baseState.Balance = baseState.AmountIncomeTotal - baseState.AmountExpenseTotal
		if baseState.Balance < 0
			throw(d.AddressId)
		end
		baseState.UsdtNetUnrealized = baseState.Balance * (coinPrice - baseState.AveragePurchasePrice)
		AddressService.SetRow(d.AddressId, baseState)
		counter += 1
	end
	return counter
	end

coinsAll = GetBlockCoins(150000)
coinsIn  = filter(x->true, coinsAll)
coinsOut = filter(x->true, coinsIn)
function InitAddressState(tmpId::UInt32, ts::Int32, tmpPrice::Float64)::Nothing
	AddressService.SetFieldTimestampCreated(tmpId, ts)
	AddressService.SetFieldAverageTradeIntervalSecs(tmpId, 3600)
	AddressService.SetFieldLastPurchasePrice(tmpId, tmpPrice)
	AddressService.SetFieldLastSellPrice(tmpId, tmpPrice)
	AddressService.SetFieldNumWinning(tmpId, 1)
	AddressService.SetFieldNumLossing(tmpId, 1)
	AddressService.SetFieldUsdtAmountWon(tmpId, 0.1)
	AddressService.SetFieldUsdtAmountLost(tmpId, 0.1)
	return nothing
	end
function SubTouchAddressState(tmpId::UInt32, ts::Int32, tmpPrice::Float64)::Nothing
	AddressService.SetFieldDiffNumTxTotal(tmpId, 1)
	AddressService.SetFieldAverageTradeIntervalSecs(tmpId,
			( AddressService.GetFieldAverageTradeIntervalSecs(tmpId) * AddressService.GetFieldNumTxTotal(tmpId) + ( ts - AddressService.GetFieldTimestampLastActive(tmpId) ) ) / ( AddressService.GetFieldNumTxTotal(tmpId) + 1 )
	)
	AddressService.SetFieldUsdtNetUnrealized(tmpId,
		AddressService.GetFieldBalance(tmpId) * (tmpPrice - AddressService.GetFieldAveragePurchasePrice(tmpId))
	)
	return nothing
	end
function MergeBlock2AddressState(n::Int)::Nothing
	empty!(coinsAll); empty!(coinsIn); empty!(coinsOut);
	append!(coinsAll, GetBlockCoins(n))
	append!(coinsIn,  filter(x->x["mintHeight"]==n, coinsAll))
	append!(coinsOut, filter(x->x["spentHeight"]==n, coinsAll))
	tmpId    = UInt32(0)
	ts       = n |> BlockNum2Timestamp
	tmpPrice = GetPriceAtBlockN(n)
	tmpAmount= 0.0
	for c in coinsIn
		tmpId = GenerateID(c["address"])
		tmpAmount = bitcoreInt2Float64(c["value"])
		if isNew(tmpId)
			InitAddressState(tmpId, ts, tmpPrice)
		elseif !isequal(ts, AddressService.GetFieldTimestampLastActive(tmpId))
			SubTouchAddressState(tmpId, ts, tmpPrice)
		end
		AddressService.SetFieldTimestampLastActive(tmpId, ts)
		AddressService.SetFieldTimestampLastReceived(tmpId, ts)
		AddressService.SetFieldDiffAmountIncomeTotal(tmpId, tmpAmount)
		AddressService.SetFieldDiffNumTxInTotal(tmpId, 1)
		AddressService.SetFieldDiffUsdtPayed4Input(tmpId, tmpPrice * tmpAmount)
		AddressService.SetFieldLastPurchasePrice(tmpId, tmpPrice)
		AddressService.SetFieldAveragePurchasePrice(tmpId,
			AddressService.GetFieldUsdtPayed4Input(tmpId) /
			AddressService.GetFieldAmountIncomeTotal(tmpId)
			)
		AddressService.SetFieldUsdtNetRealized(tmpId,
			AddressService.GetFieldUsdtReceived4Output(tmpId) - AddressService.GetFieldUsdtPayed4Input(tmpId)
			)
		AddressService.SetFieldBalance(tmpId,
			AddressService.GetFieldAmountIncomeTotal(tmpId) - AddressService.GetFieldAmountExpenseTotal(tmpId)
			)
	end
	for c in coinsOut
		tmpId = GenerateID(c["address"])
		tmpAmount = bitcoreInt2Float64(c["value"])
		if isNew(tmpId)
			InitAddressState(tmpId, ts, tmpPrice)
		elseif !isequal(ts, AddressService.GetFieldTimestampLastActive(tmpId))
			SubTouchAddressState(tmpId, ts, tmpPrice)
		end
		# judge whether winning
		if tmpPrice >= AddressService.GetFieldLastPurchasePrice(tmpId)
			if !isequal(ts, AddressService.GetFieldTimestampLastPayed(tmpId))
				AddressService.SetFieldDiffNumWinning(tmpId, 1)
			end
			AddressService.SetFieldDiffUsdtAmountWon(tmpId,
				(tmpPrice - AddressService.GetFieldLastPurchasePrice(tmpId)) * tmpAmount
			)
		else # if loss
			if !isequal(ts, AddressService.GetFieldTimestampLastPayed(tmpId))
				AddressService.SetFieldDiffNumLossing(tmpId, 1)
			end
			AddressService.SetFieldDiffUsdtAmountLost(tmpId,
				(AddressService.GetFieldLastPurchasePrice(tmpId) - tmpPrice) * tmpAmount
		end
		AddressService.SetFieldRateWinning(tmpId,
			AddressService.GetFieldNumWinning(tmpId) / ( AddressService.GetFieldNumWinning(tmpId) + AddressService.GetFieldNumLossing(tmpId) )
		)
		AddressService.SetFieldTimestampLastActive(tmpId, ts)
		AddressService.SetFieldTimestampLastPayed(tmpId, ts)
		AddressService.SetFieldDiffAmountExpenseTotal(tmpId, tmpAmount)
		AddressService.SetFieldDiffNumTxOutTotal(tmpId, 1)
		AddressService.SetFieldDiffUsdtReceived4Output(tmpId, tmpPrice * tmpAmount)
		AddressService.SetFieldLastSellPrice(tmpId, tmpPrice)
		AddressService.SetFieldUsdtNetRealized(tmpId,
			AddressService.GetFieldUsdtReceived4Output(tmpId) - AddressService.GetFieldUsdtPayed4Input(tmpId)
			)
		AddressService.SetFieldBalance(tmpId,
			AddressService.GetFieldAmountIncomeTotal(tmpId) - AddressService.GetFieldAmountExpenseTotal(tmpId)
			)
	end
	return nothing
	end



BlockPriceDict = Dict{Int, Float32}()
function SyncBlockPriceDict(fromN, toN)::Nothing
	for h in fromN:toN
		BlockPriceDict[h] = h |> BlockNum2Timestamp |> GetBTCPriceWhen
	end
	return nothing
	end
function GetPriceAtBlockN(height)::Float64
	if !haskey(BlockPriceDict, height)
		BlockPriceDict[height] = height |> BlockNum2Timestamp |> GetBTCPriceWhen
	end
	return BlockPriceDict[height]
	end
