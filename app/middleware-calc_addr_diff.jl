
using Mongoc

# include("./service-address.ng.jl");
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
function Address2StateDiff(fromBlock::Int, toBlock::Int)::Vector{AddressDiff}
	ret = Dict{UInt32, AddressDiff}()
	coinsAll = Mongoc.BSON[]
	for i in fromBlock:toBlock
		append!(coinsAll, GetBlockCoins(i))
	end
	addrs = unique(map(x->x["address"], coinsAll))
	tmpDict = Dict{String, UInt32}()
	for addr in addrs
		v = String2ID(addr)
		tmpDict[addr] = v
		ret[v] = AddressDiff(zeros(length(AddressDiff.types))...)
		ret[v].AddressId = v
	end
	for addr in addrs
		v = tmpDict[addr]
		coins     = filter(x->x["address"]==addr, coinsAll)
		spentRange= map(x->0 < x["spentHeight"] <= toBlock, coins)
		mintNums  = map(x->x["mintHeight"], coins)
		spentNums = map(x->x["spentHeight"], coins[spentRange])
		blockNums = sort!(vcat(mintNums, spentNums))
		if length(blockNums) > 0
			if length(mintNums) > 0
				ret[v].TimestampLastReceived = mintNums[end] |> BlockNum2Timestamp
				ret[v].AmountIncomeTotal = map(
					x->x["value"],
					coins
				) |> sum |> bitcoreInt2Float64
				ret[v].NumTxInTotal = length(mintNums)
			end
			if length(spentNums) > 0
				ret[v].TimestampLastPayed = spentNums[end] |> BlockNum2Timestamp
				ret[v].AmountExpenseTotal = map(
					x->x["value"],
					coins[spentRange]
				) |> sum |> bitcoreInt2Float64
				ret[v].NumTxOutTotal = length(spentNums)
			end
		end
		# LastSellPrice
			if length(spentNums) > 0
				ret[v].LastSellPrice = GetBTCPriceWhen(BlockNum2Timestamp(spentNums[end]))
			end
		# Usdt
			if length(mintNums) > 0
				ret[v].UsdtPayed4Input = map(
					x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["mintHeight"]),
					coins
				) |> sum
			end
			if length(spentNums) > 0
				ret[v].UsdtReceived4Output = map(
					x->bitcoreInt2Float64(x["value"]) * GetPriceAtBlockN(x["spentHeight"]),
					coins[spentRange]
				) |> sum
			end
	end
	return collect(values(ret))
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

function GetPriceAtBlockN(height)::Float64
	return height |> BlockNum2Timestamp |> GetBTCPriceWhen
	end

