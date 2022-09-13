
using ProgressMeter
using Dates
using CRC

@info "Please mannually drop caches for better memory performance!"
@info "echo 3 > /proc/sys/vm/drop_caches"
@info "Press Enter to continue."
readline();
const NUM_NOT_EXIST = UInt32(0)
AddressHashList = fill(NUM_NOT_EXIST, typemax(UInt64))
AddressMaxId   = UInt32(17)
AddressDupLock = Threads.SpinLock()

c64 = CRC.crc(CRC_64)

function ReadID(addr::AbstractString)::UInt32
	return AddressHashList[c64(addr)]
	end

function GenerateID(addr::AbstractString)::UInt32
	tmpCRC = c64(addr)
	tmpN = AddressHashList[tmpCRC]
	if tmpN == NUM_NOT_EXIST
		lock(AddressDupLock)
		n = AddressMaxId + UInt32(1)
		AddressHashList[tmpCRC] = n
		unlock(AddressDupLock)
		WriteAddressLine(addr, n)
		return n
	else
		return tmpN
	end
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
