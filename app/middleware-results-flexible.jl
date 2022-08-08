
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

using Statistics
import Base:merge
function merge(v::Vector{ResultCalculations})::ResultCalculations
	tmpFields  = fieldnames(typeof(v[1]))
	tmpWeights = getfield.(v, :numTotalRows)
	tmpWeights = tmpWeights / reduce(+, tmpWeights)
	tmpTypes   = typeof(v[1]).types
	retRes     = deepcopy(v[1])
	for i in 1:length(tmpFields)
		fld = tmpFields[i]
		try
			setfield!(retRes, fld, tmpTypes[i](
				sum( getfield.(v, fld) .* tmpWeights )
			))
		catch
			setfield!(retRes, fld, round(tmpTypes[i],
				sum( getfield.(v, fld) .* tmpWeights )
			))
		end
	end
	return retRes
	end
