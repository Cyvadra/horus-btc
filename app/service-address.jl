
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
	# 5th,Sep,2022 additional fields
	NumWinning::Int32
	NumLossing::Int32
	UsdtAmountWon::Float64
	UsdtAmountLost::Float64
	RateWinning::Float32
	# 14th,Mar,2023 momentum
	AverageMintTimestamp::Int32
	AverageSpentTimestamp::Int32
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
	return reduce(max, AddressService.AddressStatisticsDict[:TimestampLastActive])
	end



















