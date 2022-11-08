
using ProgressMeter
using Dates, JLD2
using CRC

@info "Please mannually drop caches for better memory performance!"
@info "echo 3 > /proc/sys/vm/drop_caches"
@info "Press Enter to continue."
readline();
const NUM_NOT_EXIST = UInt32(0)
AddressHashDict = Dict{UInt64, UInt32}()
U32_TAG_MAX     = typemax(UInt32)
AddressIdLock   = Threads.SpinLock()

c64 = CRC.crc(CRC_64)

function SaveAddressIDs(jldFilePath::AbstractString=jldAddressIdFile)::Nothing
	JLD2.save(jldFilePath, "AddressHashDict", AddressHashDict)
	return nothing
	end
function OpenAddressIDs(jldFilePath::AbstractString=jldAddressIdFile)::Nothing
	tmpRes = JLD2.load(jldFilePath)
	global AddressHashDict
	AddressHashDict = tmpRes[collect(keys(tmpRes))[1]]
	sizehint!(AddressHashDict, round(Int, 1.28e9))
	return nothing
	end

if isfile(jldAddressIdFile)
	OpenAddressIDs(jldAddressIdFile)
else
	AddressHashDict[U32_TAG_MAX] = UInt32(17)
	sizehint!(AddressHashDict, round(Int, 1.28e9))
end

function ReadID(addr::AbstractString)::UInt32
	return get(AddressHashDict, c64(addr), NUM_NOT_EXIST)
	end

function GenerateID(addr::AbstractString)::UInt32
	tmpCRC = c64(addr)
	lock(AddressIdLock)
	if haskey(AddressHashDict, tmpCRC)
		unlock(AddressIdLock)
		return AddressHashDict[tmpCRC]
	end
	n = AddressHashDict[U32_TAG_MAX] + UInt32(1)
	AddressHashDict[tmpCRC] = n
	AddressHashDict[U32_TAG_MAX] = n
	WriteAddressLine(addr, n)
	unlock(AddressIdLock)
	return n
	end

function SetID(addr::AbstractString, n::UInt32)::Nothing
	AddressHashDict[c64(addr)] = n
	if n > AddressHashDict[U32_TAG_MAX]
		lock(AddressIdLock)
		AddressHashDict[U32_TAG_MAX] = n
		unlock(AddressIdLock)
	end
	return nothing
	end

fileAddressLog = open(logAddressString, "a+")
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
