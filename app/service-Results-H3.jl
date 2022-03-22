
using MmapDB, Dates

MmapDB.Init("/mnt/data/Results-H3/")

include("./struct-ResultCalculations.jl")

TableResults = MmapDB.GenerateCode(ResultCalculations)
TableResults.Open(true) # shared = true
baseTsResults = TableResults.GetFieldTimestamp(1) - 10800

function ts2resultsInd(ts)
	if ts - baseTsResults < 10800
		return 1
	else
		return round(Int32, (ts - baseTsResults)/10800)
	end
	end


