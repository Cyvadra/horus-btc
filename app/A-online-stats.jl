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
dataFolder   = "/mnt/data/bitcore/"
counterFile  = "/mnt/data/bitcore/counter"
tsFile       = "/mnt/data/bitcore/BlockTimestamps.dict.jld2"
shuffleRng   = Random.MersenneTwister(10086)
exNumTxRows  = round(Int64, 100e8)
exNumTx      = round(Int64, 60e8)
fMode        = "w+"

# Var
GlobalStat   = ThreadSafeDict{String,Int64}()
tmpDict = JSON.Parser.parse(readline(counterFile))
BlockTimestamps = JLD2.load(tsFile)["BlockTimestamps"]
GlobalStat["PointerTxRows"] = tmpDict["PointerTxRows"]
GlobalStat["PointerTx"]     = tmpDict["PointerTx"]
GlobalStat["lastUndoneBlk"] = tmpDict["lastUndoneBlk"]

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
	collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"spentTxid\":\"$txid\"}")) )
	end
function GetCoinsOutputByTxid(txid::String, height::Int)::Vector{Mongoc.BSON}
	filter!(
		x->x["spentHeight"] <= height,
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


struct cacheTx
	addressId::UInt32
	amount::Float64
	timestamp::Int32
	end
# Union: Update Results
function ProcessBlockN(height::Int)::Vector{cacheTx}
	txs           = GetBlockTransactions(height)
	timeStamp     = round(Int, datetime2unix(txs[1]["blockTime"]))
	retList   = Vector{cacheTx}()
	tmpList   = Vector{cacheTx}()
	for tx in txs
		inputs  = GetCoinsInputByTxid(string(tx["txid"]))
		outputs = GetCoinsOutputByTxid(string(tx["txid"]), height)
		for c in inputs
			push!(minList, cacheTx(
				String2IDSafe(string(c["address"])),
				-bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		for c in outputs
			push!(tmpList, cacheTx(
				String2IDSafe(string(c["address"])),
				bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		Random.shuffle!(shuffleRng, tmpList)
		append!(retList, tmpList)
		empty!(tmpList)
	end
	return retList
	end





