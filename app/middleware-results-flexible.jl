
using MmapDB, Dates

MmapDB.Init("/mnt/data/results-flexible/")

include("./struct-ResultCalculations.jl")

TableResults = MmapDB.GenerateCode(ResultCalculations)
TableResults.Open(true) # shared = true
# id == BlockNum

function GetLastResultsID()
	return TableResults.Findlast(x->!iszero(x), :timestamp)
	end

function GetLastResultsTimestamp()::Int32
	tmpVal = GetLastResultsID()
	return max( TableResults.GetFieldTimestamp(tmpVal-3000:tmpVal)... )
	end

function GetResultsWhen(ts)::ResultCalculations
	return Timestamp2LastBlockN(ts) |> TableResults.GetRow
	end

