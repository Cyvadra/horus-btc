using JSON
using MmapDB
using ProgressMeter

include("./utils-run.jl")

BITCOIN_NULL_STRING = "nulldata"
BITCOIN_EMPTY_ADDR  = "null"
BITCOIN_CACHE_FILE  = "/tmp/bitcoin-cli.cache"
touch(BITCOIN_CACHE_FILE)
function lambdaGetBlockCoinsTx(txid::AbstractString)
	rawTx = exec("bitcoin-cli getrawtransaction $txid 3")
	JSON.Parser.parse(rawTx)
	end
function lambdaProcessInput(x)
	tmpObject = filter(xx->isequal(xx["n"],x["vout"]), lambdaGetBlockCoinsTx(x["txid"])["vout"])[1]
	return pubkey2address(tmpObject) => tmpObject["value"]
	end
function GetBlockCoins(height::Int)
	# global height, tmpHash, tmpDict, tmpTransactions, vIn, vOut, dictTx
	tmpHash = exec("bitcoin-cli getblockhash $height")
	tmpDict = JSON.Parser.parse( exec("bitcoin-cli getblock $tmpHash") )
	tmpTransactions = tmpDict["tx"]
	vIn     = []
	vOut    = []
	tmpLock = Threads.SpinLock()
	Threads.@threads for tx in tmpTransactions
		dictTx = lambdaGetBlockCoinsTx(tx)
		tmpListIn  = map(lambdaProcessInput, filter(x->haskey(x,"txid"), dictTx["vin"]))
		tmpListOut = map(x-> pubkey2address(x) => x["value"], dictTx["vout"])
		lock(tmpLock)
		append!(vIn, tmpListIn)
		append!(vOut, tmpListOut)
		unlock(tmpLock)
		dictTx = nothing
	end
	return vIn, vOut
	end
function pubkey2address(x)
	x = x["scriptPubKey"]
	if haskey(x, "address")
		return x["address"]
	elseif haskey(x, "addresses")
		return x["addresses"][1]
	elseif haskey(x, "type") && x["type"] == BITCOIN_NULL_STRING
		return BITCOIN_EMPTY_ADDR
	elseif haskey(x, "asm")
		s = sort(split(x["asm"], ' '), by=x->length(x))[end]
		return exec(pwd()*"/tools/bitcoin-tool --network dogecoin --input-format hex --input-type public-key --input $s --output-type address --output-format base58check")
	else
		throw(x)
	end
	end

# for compatibility
function GetBlockInfo(height)
	tmpHash = exec("bitcoin-cli getblockhash $height")
	tmpDict = JSON.Parser.parse( exec("bitcoin-cli getblock $tmpHash") )
	tmpDict["timeNormalized"] = unix2datetime(tmpDict["time"])
	return tmpDict
	end







# EOF