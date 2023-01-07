using BSON, Mongoc
using Dates
using JSON
using Random

dataFolder   = "/mnt/data/cacheTx/"
shuffleRng   = Random.MersenneTwister(10086)

#= NOTICE
		use bitcore;
		db.coins.ensureIndex({"spentHeight":1})
		db.coins.ensureIndex({"mintHeight":1})
=#

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
		@warn "Block $height error!"
		push!(FailedBlockNums, Int64(height))
	end
	return res
	end
	FailedBlockNums = Int[]
function GetCoinsByTxid(txid::String)::Vector{Mongoc.BSON}
	a = collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"mintTxid\":\"$txid\"}")) )
	append!(a, collect( Mongoc.find(MongoCollection("coins"), Mongoc.BSON("{\"spentTxid\":\"$txid\"}")) ) )
	end
function GetCoinsByMintHeight(height)::Vector{Mongoc.BSON}
	collect( Mongoc.find(
		MongoCollection("coins"),
		Mongoc.BSON("""{
			"chain":"BTC", "network":"mainnet", "mintHeight":$height
			}""")
		) )
	end
function GetCoinsBySpentHeight(height)::Vector{Mongoc.BSON}
	collect( Mongoc.find(
		MongoCollection("coins"),
		Mongoc.BSON("""{
			"chain":"BTC", "network":"mainnet", "spentHeight":$height
			}""")
		) )
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
	filter(x->x["mintHeight"]>0,
		sort!(
			collect(Mongoc.find(db["coins"], tmpBson)),
			by=x->x["mintHeight"]
		)
	)
	end
function GetBlockCoins(height::Int)::Vector{Mongoc.BSON} # use with caution, may cause duplicate values
	retList = collect( Mongoc.find(
		MongoCollection("coins"),
		Mongoc.BSON("""{
			"chain":"BTC", "network":"mainnet",
			"\$or": [ {"mintHeight":$height}, {"spentHeight":$height} ]
			}""")
		) )
	# Random.shuffle!(shuffleRng, retList)
	return retList
	end
function GetBlockCoinsInRange(fromBlock::Int, toBlock::Int)::Vector{Mongoc.BSON} # [fromBlock, toBlock]
	gt = fromBlock - 1
	lt = toBlock + 1
	retList = collect( Mongoc.find(
		MongoCollection("coins"),
		Mongoc.BSON("""{
			"chain":"BTC", "network":"mainnet",
			"\$or": [
				{"mintHeight": {"\$gt":$gt, "\$lt":$lt}},
				{"spentHeight": {"\$gt":$gt, "\$lt":$lt}}
			]
			}""")
		) )
	# Random.shuffle!(shuffleRng, retList)
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




