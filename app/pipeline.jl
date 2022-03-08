
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");

# Get latest timestamp
	tmpVal = findlast(x->!iszero(x), AddressService.AddressStatisticsDict[:TimestampLastActive])
	tmpVal = reduce(max, AddressService.AddressStatisticsDict[:TimestampLastActive][tmpVal-100:tmpVal]) - 1
	lastProcessedBlockN = Timestamp2LastBlockN(tmpVal)

# Sync BlockPairs
	while true
		tmpVal = BlockPairs[end][1]
		ts = round(Int32, GetBlockInfo(tmpVal+1)["timeNormalized"] |> datetime2unix)
		push!(BlockPairs, Pair{Int32, Int32}(tmpVal+1, ts))
		print(".")
	end

# Test address diff
	arrayDiff = Address2StateDiff(lastProcessedBlockN+1,lastProcessedBlockN+1)
	currentTs = BlockNum2Timestamp(lastProcessedBlockN+1)
	MergeAddressState!(arrayDiff, GetBTCPriceWhen(currentTs))



