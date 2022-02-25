using BSON, Mongoc
using Dates
using ProgressMeter
using Redis
using UnixMmap; using UnixMmap: mmap, msync!
using ThreadSafeDicts
using Random
using JSON

# Config
dataFolder   = "/mnt/data/bitcore/"
addrDictPath = "/mnt/data/bitcore/addr.latest.txt"
counterFile  = "/mnt/data/bitcore/counter"
shuffleRng   = Random.MersenneTwister(10086)
exNumTxRows  = round(Int64, 100e8)
exNumTx      = round(Int64, 60e8)
fMode        = "w+"
flagRebuild  = false

# Var
GlobalStat   = ThreadSafeDict{String,Int64}()
if flagRebuild || filesize(counterFile) == 0
	GlobalStat["PointerTxRows"] = 1
	GlobalStat["PointerTx"]     = 1
	GlobalStat["lastUndoneBlk"] = 1
else
	tmpDict = JSON.Parser.parse(readline(counterFile))
	GlobalStat["PointerTxRows"] = tmpDict["PointerTxRows"]
	GlobalStat["PointerTx"]     = tmpDict["PointerTx"]
	GlobalStat["lastUndoneBlk"] = tmpDict["lastUndoneBlk"]
end

# Structure
Address2ID = ThreadSafeDict{String,UInt32}()
FailedBlockNums = Vector{Int64}()
struct TransactionStat
	inputCount::UInt16
	outputCount::UInt16
	fee::Float32
	value::Float32
	timestamp::Int32
	end

# Set Mmap
_TxStatList      = open(dataFolder*"TxStatList.mmap", fMode)
_TxAddressIdList = open(dataFolder*"TxAddressIdList.mmap", fMode)
_TxAmountList    = open(dataFolder*"TxAmountList.mmap", fMode)
_TxTimestampList = open(dataFolder*"TxTimestampList.mmap", fMode)
TxStatList       = mmap(_TxStatList, 
	Vector{TransactionStat}, round(Int64, exNumTx); grow=false
	);
TxAddressIdList  = mmap(_TxAddressIdList,
	Vector{UInt32}, round(Int64, exNumTxRows); grow=false
	);
TxAmountList     = mmap(_TxAmountList,
	Vector{Float64}, round(Int64, exNumTxRows); grow=false
	);
TxTimestampList  = mmap(_TxTimestampList,
	Vector{Int32}, round(Int64, exNumTxRows); grow=false
	);
function saveMmap()
	UnixMmap.msync!(TxStatList)
	UnixMmap.msync!(TxAddressIdList)
	UnixMmap.msync!(TxAmountList)
	UnixMmap.msync!(TxTimestampList)
	write(counterFile, JSON.json(GlobalStat))
	end
function closeFunc()
	saveMmap()
	flush(_TxStatList); close(_TxStatList)
	flush(_TxAddressIdList); close(_TxAddressIdList)
	flush(_TxAmountList); close(_TxAmountList)
	flush(_TxTimestampList); close(_TxTimestampList)
	end
atexit(closeFunc)


# todo: load Address2ID from txt?

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
function addr2id(addr::String)::UInt32
	if !haskey(Address2ID, addr)
		Address2ID[addr] = length(Address2ID)+1
	end
	return Address2ID[addr]
	end
function addr2idSafe(addr::String)::UInt32
	if !haskey(Address2ID, addr)
		throw(addr*" not exist!")
	end
	return Address2ID[addr]
	end
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
struct procRet
	TxRows::Vector{cacheTx}
	TxStats::Vector{TransactionStat}
	end
function ProcessBlockN(height::Int)::procRet
	txs           = GetBlockTransactions(height)
	timeStamp     = datetime2unix(txs[1]["blockTime"])
	cacheList     = Vector{cacheTx}()
	cacheStat     = Vector{TransactionStat}()
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
		push!(cacheStat, TransactionStat(
				UInt16(tx["inputCount"]),
				UInt16(tx["outputCount"]),
				bitcoreInt2Float32(tx["fee"]),
				bitcoreInt2Float32(tx["value"]),
				Int32(timeStamp),
			))
		Random.shuffle!(shuffleRng, minList)
		append!(cacheList, minList)
	end
	return procRet(
			cacheList,
			cacheStat,
		)
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
			for c in resCache[i].TxRows
				j = GlobalStat["PointerTxRows"]
				TxAddressIdList[j] = c.addressId
				TxAmountList[j] = c.amount
				TxTimestampList[j] = c.timestamp
				GlobalStat["PointerTxRows"] = j+1
			end
			j = GlobalStat["PointerTx"]
			TxStatList[j:j+length(resCache[i].TxStats)-1] = resCache[i].TxStats
			GlobalStat["PointerTx"] = j+length(resCache[i].TxStats)
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


# Save addr
function SaveAddr()
	f = open(addrDictPath, "w")
	@showprogress for p in Address2ID
		write(f, p[1])
		write(f, '\t')
		write(f, string(p[2]))
		write(f, '\n')
		if rand() < 0.001
		flush(f)
		end
		end
	flush(f)
	close(f)
	end



















# Redis
# dbIndexRedis    = 1
# redisPool = [ RedisConnection(;db=dbIndexRedis) for i in 1:Threads.nthreads()]
# function SetRedisAddress(addr::String, val::UInt32)::Bool
# 	Redis.set(redisPool[Threads.threadid()], addr, string(val))
# 	end
# function GetRedisAddress(addr::String)::UInt32
# 	parse(UInt32, Redis.get(redisPool[Threads.threadid()], addr))
# 	end
# function AddressIdMax()::UInt32
# 	parse(UInt32, Redis.get(redisPool[Threads.threadid()], "AddressIdMax"))
# 	end
# function AddressIdMaxUpdate(v::UInt32)::Bool
# 	Redis.set(redisPool[Threads.threadid()], "AddressIdMax", string(v))
# 	end




#=
ratelimits
state
	Mongoc.BSON with 4 entries:
  "_id"                     => BSONObjectId("61c3012235c66b776297d1c9")
  "created"                 => DateTime("2021-12-22T10:42:41.747")
  "syncingNode:BTC:mainnet" => "HOWLS:9489:1642404860438"
  "initialSyncComplete"     => Any["BTC:mainnet"]
transactions
	Mongoc.BSON with 16 entries:
	  "_id"                 => BSONObjectId("61c3012335c66b776297d1f2")
	  "chain"               => "BTC"
	  "network"             => "mainnet"
	  "txid"                => "0e3e2357e806b6cdb1f70b54c3a3a17b6714ee1f0e68bebb44a74b1efd512098"
	  "blockHash"           => "00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048"
	  "blockHeight"         => 1
	  "blockTime"           => DateTime("2009-01-09T02:54:25")
	  "blockTimeNormalized" => DateTime("2009-01-09T02:54:25")
	  "coinbase"            => true
	  "fee"                 => 0
	  "inputCount"          => 1
	  "locktime"            => 0
	  "outputCount"         => 1
	  "size"                => 134
	  "value"               => 5.0e9
	  "wallets"             => Any[]
walletaddresses
wallets
blocks
	Mongoc.BSON with 17 entries:
  "_id"               => BSONObjectId("61c3012235c66b776297d1ed")
  "chain"             => "BTC"
  "hash"              => "00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048"
  "network"           => "mainnet"
  "bits"              => 486604799
  "height"            => 1
  "merkleRoot"        => "0e3e2357e806b6cdb1f70b54c3a3a17b6714ee1f0e68bebb44a74b1efd512098"
  "nextBlockHash"     => "000000006a625f06636b8bb6ac7b960a8d03705d1ace08b1a19da3fdcc99ddbd"
  "nonce"             => 2.57339e9
  "previousBlockHash" => "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"
  "processed"         => true
  "reward"            => 5.0e9
  "size"              => 215
  "time"              => DateTime("2009-01-09T02:54:25")
  "timeNormalized"    => DateTime("2009-01-09T02:54:25")
  "transactionCount"  => 1
  "version"           => 1
cache
coins
	Mongoc.BSON with 12 entries:
  "_id"         => BSONObjectId("61c3012335c66b776297d1ef")
  "chain"       => "BTC"
  "mintIndex"   => 0
  "mintTxid"    => "0e3e2357e806b6cdb1f70b54c3a3a17b6714ee1f0e68bebb44a74b1efd512098"
  "network"     => "mainnet"
  "address"     => "12c6DSiU4Rq3P4ZxziKxzrL5LmMBrzjrJX"
  "coinbase"    => true
  "mintHeight"  => 1
  "script"      => UInt8[0x41, 0x04, 0x96, 0xb5, 0x38, 0xe8, 0x53, 0x51, 0x9c, 0x72  …  0x73, 0xa8, 0x2c, 0xbf, 0x23, 0x42, 0xc8, 0x58, 0xee, 0xac]
  "spentHeight" => -2
  "value"       => 5.0e9
  "wallets"     => Any[]
events
	Mongoc.BSON with 4 entries:
  "_id"      => BSONObjectId("61e51b127201f12511f22ead")
  "payload"  => Dict{Any, Any}("coin"=>Dict{Any, Any}("chain"=>"BTC", "address"=>"false", "value"=>0, "mintTxid"=>"6e1ba58ba3c5a1635da4430828682c34b4721de0…
  "emitTime" => DateTime("2022-01-17T07:30:26.398")
  "type"     => "coin"
=#









