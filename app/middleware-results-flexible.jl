
using MmapDB, Dates

MmapDB.Init("/mnt/data/results-flexible/")

ResultCalculations

TableResults = MmapDB.GenerateCode(ResultCalculations)
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

