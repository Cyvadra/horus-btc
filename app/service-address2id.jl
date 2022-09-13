
using ProgressMeter
using Dates
using CRC

@info "Please mannually drop caches for better memory performance!"
@info "echo 3 > /proc/sys/vm/drop_caches"
@info "Press Enter to continue."
readline();
const NUM_NOT_EXIST = UInt32(0)
AddressHashDict = Dict{UInt64, UInt32}()
sizehint!(AddressHashDict, round(Int, 1.28e9))
AddressMaxId    = UInt32(17)
AddressIdLock  = Threads.SpinLock()

c64 = CRC.crc(CRC_64)

function ReadID(addr::AbstractString)::UInt32
	return get(AddressHashDict, c64(addr), NUM_NOT_EXIST)
	end

function GenerateID(addr::AbstractString)::UInt32
	tmpCRC = c64(addr)
	if haskey(AddressHashDict, tmpCRC)
		return AddressHashDict[tmpCRC]
	end
	lock(AddressIdLock)
	n = AddressMaxId + UInt32(1)
	AddressHashDict[tmpCRC] = n
	unlock(AddressIdLock)
	WriteAddressLine(addr, n)
	return n
	end

function SetID(addr::AbstractString, n::UInt32)::Nothing
	AddressHashDict[c64(addr)] = n
	if n > AddressMaxId
		lock(AddressIdLock)
		AddressMaxId = n
		unlock(AddressIdLock)
	end
	return nothing
	end

fileAddressLog = open(logAddressString, "w")
function WriteAddressLine(addr::AbstractString, v::UInt32)::Nothing
	write(fileAddressLog, "$addr\t$v\n")
	return nothing
	end
function FlushAddressLine()::Nothing
	flush(fileAddressLog)
	close(fileAddressLog)
	return nothing
	end
atexit(FlushAddressLine)
