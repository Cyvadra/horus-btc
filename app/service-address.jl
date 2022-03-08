
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

using DataStructures

const NUM_NOT_EXIST = UInt32(0)
const CHAR_DELIM = UInt8(0)
const ADDR_UNIT_SIZE = 65535
ADDR_NUM_MAX = 930830585
AddressStringLock = Threads.SpinLock()

RootP2PKH  = Trie{IOBuffer}()
RootP2SH   = Trie{IOBuffer}()
RootBech32 = Trie{IOBuffer}()
RootOther  = Dict{String, UInt32}()
const headP2PKH  = Char(0x31)
const headP2SH   = Char(0x33)
const headBech32 = Char(0x62)
const headRangeP2PKH  = 2:4
const headRangeP2PSH  = 2:4
const headRangeBech32 = 5:8

function seeknext(needle, io::IOBuffer)
	counterN = 1
	counterI = 0
	seek(io,0)
	_len = length(needle)-1
	while !eof(io)
		counterI += 1
		if read(io, UInt8) == needle[counterN]
			if counterN > _len
				return counterI
			end
			counterN += 1
		else
			counterN = 1
		end
	end
	return nothing
	end

function ReadID(addr::AbstractString)::UInt32
	addrv = transcode(UInt8, string(addr))
	if addr[1] == headP2PKH
		io = RootP2PKH[addr[headRangeP2PKH]]
		v = seeknext(addrv[5:end], io)
		if !isnothing(v)
			seek(io, v)
			read(io, UInt8)
			return read(io, UInt32)
		end
	elseif addr[1] == headP2SH
		io = RootP2SH[addr[headRangeP2PSH]]
		v = seeknext(addrv[5:end], io)
		if !isnothing(v)
			seek(io, v)
			read(io, UInt8)
			return read(io, UInt32)
		end
	elseif addr[1] == headBech32
		io = RootBech32[addr[headRangeBech32]]
		v = seeknext(addrv[9:end], io)
		if !isnothing(v)
			seek(io, v)
			read(io, UInt8)
			return read(io, UInt32)
		end
	else
		if haskey(RootOther, addr)
			return RootOther[addr]
		end
	end
	return NUM_NOT_EXIST
	end

function SetID(addr::AbstractString, id::UInt32)::Nothing
	addrv = transcode(UInt8, string(addr))
	if addr[1] == headP2PKH
		if !haskey(RootP2PKH, addr[headRangeP2PKH])
			RootP2PKH[addr[headRangeP2PKH]] = IOBuffer(;sizehint=ADDR_UNIT_SIZE)
		end
		io = RootP2PKH[addr[headRangeP2PKH]]
		v  = seeknext(addrv[5:end], io)
		if !isnothing(v)
			seek(io, v)
			write(io, CHAR_DELIM)
			write(io, id)
			write(io, CHAR_DELIM)
		else
			seekend(io)
			write(io, addrv[5:end])
			write(io, CHAR_DELIM)
			write(io, id)
			write(io, CHAR_DELIM)
		end
		flush(io)
		seek(io, 0)
	elseif addr[1] == headP2SH
		if !haskey(RootP2SH, addr[headRangeP2PSH])
			RootP2SH[addr[headRangeP2PSH]] = IOBuffer(;sizehint=ADDR_UNIT_SIZE)
		end
		io = RootP2SH[addr[headRangeP2PSH]]
		v  = seeknext(addrv[5:end], io)
		if !isnothing(v)
			seek(io, v)
			write(io, CHAR_DELIM)
			write(io, id)
			write(io, CHAR_DELIM)
		else
			seekend(io)
			write(io, addrv[5:end])
			write(io, CHAR_DELIM)
			write(io, id)
			write(io, CHAR_DELIM)
		end
		flush(io)
		seek(io, 0)
	elseif addr[1] == headBech32
		if !haskey(RootBech32, addr[headRangeBech32])
			RootBech32[addr[headRangeBech32]] = IOBuffer(;sizehint=ADDR_UNIT_SIZE)
		end
		io = RootBech32[addr[headRangeBech32]]
		v  = seeknext(addrv[9:end], io)
		if !isnothing(v)
			seek(io, v)
			write(io, CHAR_DELIM)
			write(io, id)
			write(io, CHAR_DELIM)
		else
			seekend(io)
			write(io, addrv[9:end])
			write(io, CHAR_DELIM)
			write(io, id)
			write(io, CHAR_DELIM)
		end
		flush(io)
		seek(io, 0)
	else
		RootOther[addr] = id
	end
	return nothing
	end



















