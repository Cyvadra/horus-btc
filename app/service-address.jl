
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

#=========================================# 

const NUM_NOT_EXIST = UInt32(0)
const TAG_MAX = "maximum"
# TAG_MAX = 930830585
AddressStringLock = Threads.SpinLock()
AddressIOBufferDict = Dict{UInt8, IOBuffer}()

function ReadID(addr::AbstractString)::UInt32
	addrv = transcode(UInt8, addr)
	_len  = UInt8(length(addrv))
	if addrv[1] == 0x31
		io = AddressIOBufferDict[_len]
		v = readuntil(io, addrv[2:end])
		if length(v) > 0
			skip(io, 1)
			return read(io, UInt32)
		end
	# elseif addrv[1] == 0x33
	# 	v = readuntil(AddressIOBufferDict(length(addrv)), addrv)
	# elseif addrv[1] == 0x62
	# 	v = readuntil(AddressIOBufferDict(length(addrv)), addrv)
	end
	return NUM_NOT_EXIST
	end

function SetID(addr::AbstractString, id::UInt32)::Nothing
	addrv = transcode(UInt8, addr)
	_len  = UInt8(length(addrv))
	if addrv[1] == 0x31
		if !haskey(AddressIOBufferDict, _len)
			AddressIOBufferDict[_len] = IOBuffer()
		end
		io = AddressIOBufferDict[_len]
		v = readuntil(io, addrv[2:end])
		if length(v) > 0
			skip(io, 1)
			write(io, id)
			return nothing
		else
			write(io, addrv[2:end])
			write(io, zero(UInt8))
			return nothing
		end
	end
	end



















