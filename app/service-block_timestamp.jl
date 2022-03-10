using JLD2

tsFile = "/mnt/data/bitcore/BlockTimestamps.dict.jld2"

# BlockNum 2 Timestamp ( Dict{Int32, Int32} )
# [!!!NOTICE!!!] Preload all of transaction data!
# to avoid parallel-computing trouble
BlockTimestamps = Dict{Int32, Int32}()
BlockPairs = Vector{Pair{Int32,Int32}}()
if filesize(tsFile) > 0
	BlockTimestamps = JLD2.load(tsFile)["BlockTimestamps"]
	BlockPairs = sort!(collect(BlockTimestamps), by=x->x[2])
end
function BlockNum2Timestamp(height)::Int32
	return BlockTimestamps[height]
	end
#=
	BlockTimestamps[b["height"]] = round(Int32, 
		datetime2unix(
			b["timeNormalized"]
		)
	) for b in collect(
			Mongoc.find(MongoCollection("blocks"),  Mongoc.BSON("{}"))
	)
=#
function ResyncBlockPairs()
	global BlockPairs
	BlockPairs = sort!(collect(BlockTimestamps), by=x->x[2])
	return BlockPairs
	end
function ResyncBlockTimestamps()
	global BlockTimestamps
	BlockTimestamps = Dict(BlockPairs)
	return BlockTimestamps
	end
function Timestamp2LastBlockN(ts)::Int
	i = findlast(x->x<=ts, map(x->x[2], BlockPairs))
	return BlockPairs[i][1]
	end
function SyncBlockTimestamps()
	JLD2.save(tsFile, "BlockTimestamps", BlockTimestamps)
	return nothing
	end
atexit(SyncBlockTimestamps)
