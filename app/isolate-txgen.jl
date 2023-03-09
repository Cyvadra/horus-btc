include("./config.jl")
include("./service-address2id.jl")
include("./service-mongo.jl")

using MmapDB

MmapDB.Init(folderTransactions)

struct cacheTx
	addressId::UInt32
	addressPreviousBalance::Float64
	mintHeight::Int32
	spentHeight::Int32
	amount::Float64
	timestamp::UInt32
	end
function ProcessBlockN(height::Int)::Vector{cacheTx}
	txs       = GetBlockTransactions(height)
	timeStamp = UInt32(round(Int, datetime2unix(txs[1]["blockTime"])))
	tmpList   = Vector{cacheTx}()
	tmpDict   = Dict{String,UInt32}()
	for tx in txs
		inputs  = GetCoinsInputByTxid(string(tx["txid"]))
		outputs = GetCoinsOutputByTxid(string(tx["txid"]), height)
		addrs   = unique(vcat(
			map(x->x["address"], inputs),
			map(x->x["address"], outputs),
			))
		for addr in addrs
			if !haskey(tmpDict, addr)
				tmpDict[addr] = ReadID(addr)
			end
		end
		for c in inputs
			push!(tmpList, cacheTx(
				tmpDict[c["address"]],
				0.0,
				c["mintHeight"],
				c["spentHeight"],
				-bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
		for c in outputs
			push!(tmpList, cacheTx(
				tmpDict[c["address"]],
				0.0,
				c["mintHeight"],
				c["spentHeight"],
				bitcoreInt2Float64(c["value"]),
				timeStamp
				))
		end
	end
	empty!(tmpDict)
	tmpDict = nothing
	# JLD2.save(dataFolder * "$height.jld2", "txList", tmpList)
	return tmpList
	end

TableTx = MmapDB.GenerateCode(cacheTx)
TableTx.Open(true)




















