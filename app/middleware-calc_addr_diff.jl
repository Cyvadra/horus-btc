
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
		counterNext = 2
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
					coins[mintNums]
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
		baseState.UsdtNetUnrealized = baseState.Balance * (coinPrice - baseState.AveragePurchasePrice)
		AddressService.SetRow(d.AddressId, baseState)
		counter += 1
	end
	return counter
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
