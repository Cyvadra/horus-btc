
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");


lastProcessedBlockN = Timestamp2LastBlockN(1642865146)

arrayDiff = Address2StateDiff(lastProcessedBlockN+1,lastProcessedBlockN+1)
currentTs = round(Int,
		(Dates.now() - Hour(24)) |> datetime2unix)
MergeAddressState!(arrayDiff, GetBTCPriceWhen(currentTs))



