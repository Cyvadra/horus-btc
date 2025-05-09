
using ProgressMeter
using Dates

AddressStringDict = Dict{String,UInt32}()
const NUM_NOT_EXIST = UInt32(0)
const TAG_MAX = "maximum"
AddressStringDict[TAG_MAX] = 1
AddressStringLock = Threads.SpinLock()

tmpCache = Dict{Bool, String}()
@info "$(now()) loading address list..."
f = open(fileAddressString, "r")
tmpCache[true] = readline(f)
prog = Progress(1013371292) # modify here

for i in 1:1000 # initial loop for sizehint
	s = split(tmpCache[true],'\t')
	tmpVal = parse(UInt32, s[2])
	if tmpVal > AddressStringDict[TAG_MAX]
		AddressStringDict[TAG_MAX] = tmpVal
	end
	AddressStringDict[s[1]] = tmpVal
	tmpCache[true] = readline(f)
	next!(prog)
	end
sizehint!(AddressStringDict, round(Int, 1.28e9))

while length(tmpCache[true])>0
	s = split(tmpCache[true],'\t')
	tmpVal = parse(UInt32, s[2])
	if tmpVal > AddressStringDict[TAG_MAX]
		AddressStringDict[TAG_MAX] = tmpVal
	end
	AddressStringDict[s[1]] = tmpVal
	tmpCache[true] = readline(f)
	next!(prog)
	end
@info "$(now()) loaded, doing gc"
close(f)
tmpCache = nothing
f = nothing
GC.gc(true)
@info "$(now()) gc complete" 



function ReadID(addr::AbstractString)::UInt32
	get(AddressStringDict, addr, NUM_NOT_EXIST)
	end

function GenerateID(addr::AbstractString)::UInt32
	lock(AddressStringLock)
	if !haskey(AddressStringDict, addr)
		n = UInt32(AddressStringDict[TAG_MAX] + 1)
		AddressStringDict[addr] = n
		AddressStringDict[TAG_MAX] = n
		# write(runtimeAddressFile, "$addr\t$n\n")
		unlock(AddressStringLock)
		return n
	else
		unlock(AddressStringLock)
		return AddressStringDict[addr]
	end
	end

function WriteAddressStringDict(path::AbstractString="/mnt/data/bitcore/addr.autosave.txt")
	@info "$(now()) Auto saving AddressStringDict..."
	lock(AddressStringLock)
	f = open(path, "w")
	_len = length(AddressStringDict)
	@showprogress for p in AddressStringDict
		write(f, "$(p[1])\t$(p[2])\n")
	end
	unlock(AddressStringLock)
	close(f)
	return filesize(path)
	end
# atexit(WriteAddressStringDict)
