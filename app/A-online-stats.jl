using BSON, Mongoc
using Dates
using ProgressMeter
using ThreadSafeDicts
using Random
using JSON
using JLD2
using MmapDB

include("./service-address2id.jl");

# load data
tsFile          = "/mnt/data/bitcore/BlockTimestamps.dict.jld2"

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
				tmpDict[addr] = String2ID(addr)
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
