
using MmapDB

MmapDB.Init("/mnt/data/AddressServiceDB/")

mutable struct AddressStatistics
	# timestamp
	TimestampCreated::Int32
	TimestampLastActive::Int32
	TimestampLastReceived::Int32
	TimestampLastPayed::Int32
	# amount
	AmountIncomeTotal::Float64
	AmountExpenseTotal::Float64
	# statistics
	NumTxInTotal::Int32
	NumTxOutTotal::Int32
	# relevant usdt amount
	UsdtPayed4Input::Float64
	UsdtReceived4Output::Float64
	AveragePurchasePrice::Float32
	LastSellPrice::Float32
	# calculated extra
	UsdtNetRealized::Float64
	UsdtNetUnrealized::Float64
	Balance::Float64
	end

AddressService = MmapDB.GenerateCode(AddressStatistics)
function isNew(i::UInt32)::Bool
	return iszero(AddressService.GetFieldTimestampCreated(i))
	end
function isNew(ids::Vector{UInt32})::Vector{Bool}
	return AddressService.mapFunctionOnFieldIds(iszero, :TimestampCreated, ids)
	end


























