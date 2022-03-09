
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");

# Init
	AddressService.Open(false) # shall always

# Get latest timestamp
	tmpVal = findlast(x->!iszero(x), AddressService.AddressStatisticsDict[:TimestampLastActive])
	tmpVal = reduce(max, AddressService.AddressStatisticsDict[:TimestampLastActive][tmpVal-100:tmpVal]) - 1
	lastProcessedBlockN = Int(Timestamp2LastBlockN(tmpVal))

# Sync BlockPairs
	latestBlockHeight = 1
	while true
		latestBlockHeight = BlockPairs[end][1]
		ts = round(Int32, GetBlockInfo(latestBlockHeight+1)["timeNormalized"] |> datetime2unix)
		push!(BlockPairs, Pair{Int32, Int32}(latestBlockHeight+1, ts))
		print(".")
	end
	ResyncBlockTimestamps()

# Test address diff
	# todo: partitions
	arrayDiff = Address2StateDiff(lastProcessedBlockN, latestBlockHeight)
	currentTs = BlockNum2Timestamp(latestBlockHeight)
	MergeAddressState!(arrayDiff, GetBTCPriceWhen(currentTs))



