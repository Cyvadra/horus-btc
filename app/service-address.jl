
using MmapDB

MmapDB.Init(folderAddressDB)

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
	NumTxTotal::Int32
	AverageTradeIntervalSecs::Int32
	# relevant usdt amount
	UsdtPayed4Input::Float64
	UsdtReceived4Output::Float64
	AveragePurchasePrice::Float32
	LastPurchasePrice::Float32
	LastSellPrice::Float32
	# calculated extra
	UsdtNetRealized::Float64
	UsdtNetUnrealized::Float64
	NumWinning::Int32
	NumLossing::Int32
	UsdtAmountWon::Float64
	UsdtAmountLost::Float64
	RateWinning::Float32
	# basic
	Balance::Float64
	end

AddressService = MmapDB.GenerateCode(AddressStatistics)
function isNew(i::UInt32)::Bool
	return iszero(AddressService.GetFieldTimestampCreated(i))
	end
function isNew(ids::Vector{UInt32})::Vector{Bool}
	return AddressService.mapFunctionOnFieldIds(iszero, :TimestampCreated, ids)
	end

function GetLastProcessedTimestamp()::Int32
	tmpVal = AddressService.Findlast(x->!iszero(x), :TimestampLastActive)
	return max( AddressService.GetFieldTimestampLastActive(tmpVal-3000:tmpVal+100)... )
	end



















