using BSON, Mongoc
using Dates
using ProgressMeter
using ThreadSafeDicts
using Random
using JSON
using JLD2
using MmapDB

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

# Init Pool
mongoClients = [ Mongoc.Client("mongodb://localhost:27017") for i in 1:Threads.nthreads() ]
mongoDBs    = map(x->x["bitcore"], mongoClients)
@show collect(Mongoc.find_collections(db))
function MongoCollection(key::String)::Mongoc.Collection
	return mongoDBs[Threads.threadid()][key]
	end

# Methods: Get data from mongodb
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
function GetCoinsOutputByTxid(txid::String)::Vector{Mongoc.BSON}
	collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"mintTxid\":\"$txid\"}")) )
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

struct cacheTx
	addressId::UInt32
	amount::Float64
	timestamp::Int32
	end
# Union: Update Results
function ProcessBlockN(height::Int)::Vector{cacheTx}
	txs           = GetBlockTransactions(height)
	timeStamp     = datetime2unix(txs[1]["blockTime"])
	cacheList     = Vector{cacheTx}()
	for tx in txs
		inputs  = GetCoinsInputByTxid(string(tx["txid"]))
		outputs = GetCoinsOutputByTxid(string(tx["txid"]))
		minList = Vector{cacheTx}()
		for c in inputs
			push!(minList, cacheTx(
				addr2id(string(c["address"])),
				-bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		for c in outputs
			push!(minList, cacheTx(
				addr2id(string(c["address"])),
				bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		Random.shuffle!(shuffleRng, minList)
		append!(cacheList, minList)
	end
	return cacheList
	end

function SyncBlocks(endWhen::Int=720000)
	batchSize  = Threads.nthreads() * 2
	lastDone   = GlobalStat["lastUndoneBlk"] - 1
	@show now()
	@info "Starting from Block: $(GlobalStat["lastUndoneBlk"])"
	resCache = Vector{Any}(undef, batchSize*2)
	flagFlip = false
	tmpRanges= Dict{Bool,UnitRange{Int64}}(
		false => 1:batchSize,
		true  => batchSize+1:2*batchSize,
		)
	prvTask  = @async Threads.@threads for i in copy(tmpRanges[flagFlip])
			resCache[i] = ProcessBlockN(lastDone+i)
		end
	flagFlip = !flagFlip
	while lastDone < endWhen
		# wait previous task result
		wait(prvTask)
		lastDone = lastDone + batchSize
		# new task
		prvTask  = @async Threads.@threads for i in copy(tmpRanges[flagFlip])
			resCache[i] = ProcessBlockN(lastDone+i)
		end
		# switch flag to read previous result
		flagFlip = !flagFlip
		for i in copy(tmpRanges[flagFlip])
			for c in resCache[i]
				j = GlobalStat["PointerTxRows"]
				TxAddressIdList[j] = c.addressId
				TxAmountList[j] = c.amount
				TxTimestampList[j] = c.timestamp
				GlobalStat["PointerTxRows"] = j+1
			end
			GlobalStat["PointerTx"] += length(resCache[i])
		end
		GlobalStat["lastUndoneBlk"] = lastDone + 1
		print("$lastDone \t")
		# keep flagFlip for next turn input
	end
	end

# Experimental
function GetAddressCoins(addr::String)::Vector{Mongoc.BSON}
	tmpBson = Mongoc.BSON("""{
		"chain":"BTC", "network":"mainnet", "address":"$addr"
		}""")
	collect(Mongoc.find(db["coins"], tmpBson))
	end
function GetBlockCoins(height::Int)::Vector{Mongoc.BSON}
	txs       = GetBlockTransactions(height)
	# timeStamp = datetime2unix(txs[1]["blockTime"])
	tmpList   = Vector{Mongoc.BSON}()
	for tx in txs
		inputs  = GetCoinsInputByTxid(string(tx["txid"]))
		outputs = GetCoinsOutputByTxid(string(tx["txid"]))
		append!(tmpList, inputs)
		append!(tmpList, outputs)
	end
	return tmpList
	end






