include("./config.jl")
include("./service-address2id.jl")
include("./service-mongo.jl")

using MmapDB, ProgressMeters

MmapDB.Init(folderTransactions)

mutable struct cacheTx
	addressId::UInt32
	blockNum::Int32
	balanceBeforeBlock::Float64
	balanceAfterBlock::Float64
	mintHeight::Int32
	spentHeight::Int32
	amount::Float64
	timestamp::UInt32
	end
TableTx = MmapDB.GenerateCode(cacheTx)
TableTx.Open(true)
# TableTx.Create!(round(Int, 1.99e10))



tmpBalanceDict = Dict{UInt32,Float64}()
sizehint!(tmpBalanceDict, round(Int,1.28e9))
tmpBalanceDiffDict = Dict{UInt32,Float64}()
function ProcessBlockN(height::Int)
	timeStamp = UInt32(round(Int, datetime2unix(
		GetBlockInfo(height)["timeNormalized"]
		)))
	tmpCoins = GetBlockCoins(height)
	tmpList  = Vector{cacheTx}()
	@assert length(tmpBalanceDiffDict) == 0
	# proceed block coins
		inputs  = filter(x->x["spentHeight"]==height, tmpCoins)
		outputs = filter(x->x["mintHeight"]==height, tmpCoins)
		addrs   = unique(vcat(
			map(x->x["address"], inputs),
			map(x->x["address"], outputs),
			))
		sizehint!(tmpBalanceDiffDict, length(addrs))
		for addr in addrs
			if !haskey(tmpBalanceDict, GenerateID(addr))
				tmpBalanceDict[HardReadID(addr)] = 0.0
			end
			tmpBalanceDiffDict[HardReadID(addr)] = 0.0
		end
		tmpAmount = 0.0
		for c in inputs
			tmpAmount = -bitcoreInt2Float64(c["value"])
			push!(tmpList, cacheTx(
				HardReadID(c["address"]),
				height,
				tmpBalanceDict[HardReadID(c["address"])],
				0.0,
				c["mintHeight"],
				c["spentHeight"],
				tmpAmount,
				timeStamp,
				))
			tmpBalanceDiffDict[HardReadID(c["address"])] += tmpAmount
		end
		for c in outputs
			tmpAmount = bitcoreInt2Float64(c["value"])
			push!(tmpList, cacheTx(
				HardReadID(c["address"]),
				height,
				tmpBalanceDict[HardReadID(c["address"])],
				0.0,
				c["mintHeight"],
				c["spentHeight"],
				tmpAmount,
				timeStamp,
				))
			tmpBalanceDiffDict[HardReadID(c["address"])] += tmpAmount
		end
		for i in 1:length(tmpList)
			tmpList[i].balanceAfterBlock = tmpList[i].balanceBeforeBlock + tmpBalanceDiffDict[tmpList[i].addressId]
		end
		empty!(tmpBalanceDiffDict)
	# save to disk
		TableTx.BatchInsert(tmpList)
	end

@showprogress for i in 1:780000
	ProcessBlockN(i)
	end



















