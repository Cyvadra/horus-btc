
using MmapDB, Dates

MmapDB.Init(folderResults)

ResultCalculations

TableResults = MmapDB.GenerateCode(ResultCalculations)
# id == BlockNum

function GetLastResultsID()
	return TableResults.Findlast(x->!iszero(x), :numTotalActive)
	end

function GetLastResultsTimestamp()::Int32
	return TableResults.GetFieldTimestamp(GetLastResultsID())
	end

function GetResultsWhen(ts)::ResultCalculations
	return Timestamp2LastBlockN(ts) |> TableResults.GetRow
	end

