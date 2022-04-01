
using MmapDB, Dates

MmapDB.Init("/mnt/data/results-flexible/")

include("./struct-ResultCalculations.jl")

TableResults = MmapDB.GenerateCode(ResultCalculations)
TableResults.Open(true) # shared = true
# id == BlockNum

function GetLastResultsTimestamp()::Int32
	tmpVal = TableResults.Findlast(x->!iszero(x), :timestamp)
	return max( TableResults.GetFieldTimestamp(tmpVal-3000:tmpVal)... )
	end
