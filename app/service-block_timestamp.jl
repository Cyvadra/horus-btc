using MmapDB

MmapDB.Init(folderBlockPairs)

mutable struct BlockTimestamp
	BlockNum::Int32
	Timestamp::Int32
end

TableBlockTimestamp = MmapDB.GenerateCode(BlockTimestamp)
TableBlockTimestamp.Open(true)

function BlockNum2Timestamp(height)::Int32
	return TableBlockTimestamp.GetFieldTimestamp(height)
	end
function Timestamp2LastBlockN(ts)::Int
	return TableBlockTimestamp.Findlast(x->!iszero(x) && x<=ts, :Timestamp)
	end
function Timestamp2FirstBlockN(ts)::Int
	return TableBlockTimestamp.Findfirst(x->x>=ts, :Timestamp)
	end
function GetLastBlockNum()::Int
	return TableBlockTimestamp.Findlast(x->!iszero(x), :BlockNum) |> TableBlockTimestamp.GetFieldBlockNum
	end
function GetLastBlockTs()::Int32
	return TableBlockTimestamp.Findlast(x->!iszero(x), :Timestamp) |> TableBlockTimestamp.GetFieldTimestamp
	end
