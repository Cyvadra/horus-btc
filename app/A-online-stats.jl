using BSON, Mongoc
using Dates
using ProgressMeter
using ThreadSafeDicts
using Random
using JSON
using JLD2
using MmapDB

# load address service
include("./service-address2id.jl");

# Config
dataFolder   = "/mnt/data/cacheTx/"
shuffleRng   = Random.MersenneTwister(10086)
tsFile       = "/mnt/data/bitcore/BlockTimestamps.dict.jld2"

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
function GetBlockInfo(height::Int)::Mongoc.BSON
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

# BlockNum 2 Timestamp
BlockTimestamps = JLD2.load(tsFile)["BlockTimestamps"]
function BlockNum2Timestamp(height::Int)::Int32
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
function SyncBlockTimestamps()
	JLD2.save(tsFile, "BlockTimestamps", BlockTimestamps)
	return nothing
	end
atexit(SyncBlockTimestamps)

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
function Address2State(addr::String)
	coins = GetCoinsByAddress(addr)
	ret   = AddressStatistics(
		0, # TimestampCreated Int32
		0, # TimestampLastActive Int32
		0, # TimestampLastReceived Int32
		0, # TimestampLastPayed Int32
		0, # AmountIncomeTotal Float64
		0, # AmountExpenseTotal Float64
		0, # NumTxInTotal Int32
		0, # NumTxOutTotal Int32
		0, # UsdtPayed4Input Float64
		0, # UsdtReceived4Output Float64
		0, # AveragePurchasePrice Float32
		0, # LastSellPrice Float32
		0, # UsdtNetRealized Float64
		0, # UsdtNetUnrealized Float64
		0, # Balance Float64
		)


