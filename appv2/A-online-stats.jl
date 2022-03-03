using BSON, Mongoc
using Dates
using ProgressMeter
using ThreadSafeDicts
using Random
using JSON
using JLD2
using MmapDB

include("./service-address2id.mem.jl");

# load data
tsFile          = "/mnt/data/bitcore/BlockTimestamps.dict.jld2"
addrCacheFolder = "/media/jason89757/gloway/addrCache/"

# load FinanceDB service
using FinanceDB
FinanceDB.SetDataFolder("/mnt/data/mmap")
pairName     = "BTC_USDT"

# Config
dataFolder   = "/mnt/data/cacheTx/"
shuffleRng   = Random.MersenneTwister(10086)
BlockPriceDict = Dict{Int32,Float64}()

# Init Mongo
client = Mongoc.Client("mongodb://localhost:27017")
@show Mongoc.ping(client)
db     = client["bitcore"]

# Mongo Connection Pool
mongoClients = [ Mongoc.Client("mongodb://localhost:27017") for i in 1:Threads.nthreads() ]
mongoDBs    = map(x->x["bitcore"], mongoClients)
@show collect(Mongoc.find_collections(db))
function MongoCollection(key::String)::Mongoc.Collection
	return mongoDBs[Threads.threadid()][key]
	end

# Middlewares: Get data from mongodb
function GetBlockInfo(height)::Mongoc.BSON
	return Mongoc.find_one(MongoCollection("blocks"),  Mongoc.BSON("{\"height\":$height}"))
	end
function GetBlockTransactions(height::Int)::Vector{Mongoc.BSON}
	block     = Mongoc.find_one(MongoCollection("blocks"),  Mongoc.BSON("{\"height\":$height}"))
	blockHash = block["hash"]
	res       = collect( Mongoc.find(MongoCollection("transactions"), Mongoc.BSON("{\"blockHash\":\"$blockHash\"}")) )
	if !isequal(length(res), block["transactionCount"])
		push!(FailedBlockNums, Int64(height))
	end
	return res
	end
function GetCoinsByTxid(txid::String)::Vector{Mongoc.BSON}
	a = collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"mintTxid\":\"$txid\"}")) )
	append!(a, collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"spentTxid\":\"$txid\"}")) ) )
	end
function GetCoinsInputByTxid(txid::String)::Vector{Mongoc.BSON}
	filter!(
		x->x["value"] > 0,
		collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"spentTxid\":\"$txid\"}")) )
		)
	end
function GetCoinsOutputByTxid(txid::String, height::Int)::Vector{Mongoc.BSON}
	filter!(
		x->x["spentHeight"] <= height && x["value"] > 0,
		collect(
			Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"mintTxid\":\"$txid\"}"))
			)
		)
	end
function GetCoinsByAddress(addr::String)::Vector{Mongoc.BSON}
	collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"address\":\"$addr\"}")) )
	end

# Basic: Global result procedure
function bitcoreInt2Float64(i)::Float64
	Float64(i) / 1e8
	end
function bitcoreInt2Float32(i)::Float32
	Float32(i) / 1e8
	end
function str2unixtime(str::String)::Int64
	dt = Dates.DateTime(str, dateformat"yyyy-mm-ddTHH:MM:SS.s\Z")
	return round(Int64, datetime2unix(dt))
	end

# Union
function GetAddressCoins(addr::String)::Vector{Mongoc.BSON}
	tmpBson = Mongoc.BSON("""{
		"chain":"BTC", "network":"mainnet", "address":"$addr"
		}""")
	collect(Mongoc.find(db["coins"], tmpBson))
	end
function GetBlockCoins(height::Int)::Vector{Mongoc.BSON}
	txs       = GetBlockTransactions(height)
	# timeStamp = datetime2unix(txs[1]["blockTime"])
	retList   = Vector{Mongoc.BSON}()
	tmpList = Vector{Mongoc.BSON}()
	for tx in txs
		inputs  = GetCoinsInputByTxid(string(tx["txid"]))
		outputs = GetCoinsOutputByTxid(string(tx["txid"]), height)
		append!(tmpList, inputs)
		append!(tmpList, outputs)
		Random.shuffle!(shuffleRng, tmpList)
		append!(retList, tmpList)
		empty!(tmpList)
	end
	return retList
	end

# Transfer into Vector{cacheTx}
struct cacheTx
	addressId::UInt32
	amount::Float64
	timestamp::Int32
	end
function ProcessBlockN(height::Int)::Vector{cacheTx}
	txs           = GetBlockTransactions(height)
	timeStamp     = round(Int, datetime2unix(txs[1]["blockTime"]))
	retList   = Vector{cacheTx}()
	tmpList   = Vector{cacheTx}()
	tmpDict   = Dict{String,UInt32}()
	for tx in txs
		inputs  = GetCoinsInputByTxid(string(tx["txid"]))
		outputs = GetCoinsOutputByTxid(string(tx["txid"]), height)
		addrs   = unique(map(x->x["address"], vcat(inputs, outputs)))
		for addr in addrs
			if !haskey(tmpDict, addr)
				tmpDict[addr] = GenerateID(addr)
			end
		end
		for c in inputs
			push!(tmpList, cacheTx(
				tmpDict[c["address"]],
				-bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		for c in outputs
			push!(tmpList, cacheTx(
				tmpDict[c["address"]],
				bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		Random.shuffle!(shuffleRng, tmpList)
		append!(retList, tmpList)
		empty!(tmpList)
	end
	empty!(tmpDict)
	JLD2.save(dataFolder * "$height.jld2", "txList", retList)
	return retList
	end

# BlockNum 2 Timestamp ( Dict{Int32, Int32} )
# [!!!NOTICE!!!] Preload all of transaction data!
# to avoid parallel-computing trouble
BlockTimestamps = JLD2.load(tsFile)["BlockTimestamps"]
BlockPairs = sort!(collect(BlockTimestamps), by=x->x[2])
function BlockNum2Timestamp(height)::Int32
	if haskey(BlockTimestamps, height)
		return BlockTimestamps[height]
	end
	BlockTimestamps[height] = round(Int32, 
		datetime2unix(
			GetBlockInfo(height)["timeNormalized"]
		)
	)
	return BlockTimestamps[height]
	end
function ResyncBlockPairs()::Nothing
	BlockPairs = sort!(collect(BlockTimestamps), by=x->x[2])
	return nothing
	end
function Timestamp2LastBlockN(ts)::Int32
	i = findlast(x->x<=ts, map(x->x[2], BlockPairs))
	return BlockPairs[i][1]
	end
function SyncBlockTimestamps()
	JLD2.save(tsFile, "BlockTimestamps", BlockTimestamps)
	return nothing
	end
atexit(SyncBlockTimestamps)

# Prepare: blockNum => coinPrice
function SyncBlockPriceDict(fromN, toN)::Nothing
	for h in fromN:toN
		BlockPriceDict[h] = FinanceDB.GetDerivativePriceWhen(pairName, BlockNum2Timestamp(h))
	end
	return nothing
	end
function GetPriceAtBlockN(height)::Float64
	if !haskey(BlockPriceDict, height)
		BlockPriceDict[height] = FinanceDB.GetDerivativePriceWhen(pairName, BlockNum2Timestamp(height))
	end
	return BlockPriceDict[height]
	end


#==============================================#


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

