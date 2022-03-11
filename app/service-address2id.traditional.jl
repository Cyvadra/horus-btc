
using ProgressMeter
using Dates

AddressStringDict = Dict{String,UInt32}()
const NUM_NOT_EXIST = UInt32(0)
const TAG_MAX = "maximum"
AddressStringDict[TAG_MAX] = 930830585
AddressStringLock = Threads.SpinLock()


@show now()
f = readlines("/mnt/data/bitcore/addr.latest.txt")
@show now()
@showprogress for l in f
	s = split(l,'\t')
	AddressStringDict[s[1]] = parse(UInt32, s[2])
	end
@show now()
empty!(f)
f = nothing
varinfo(r"f")
GC.gc()



function ReadID(addr::AbstractString)::UInt32
	get(AddressStringDict, addr, NUM_NOT_EXIST)
	end

function GenerateID(addr::AbstractString)::UInt32
	if !haskey(AddressStringDict, addr)
		lock(AddressStringLock)
		n = UInt32(AddressStringDict[TAG_MAX] + 1)
		AddressStringDict[addr] = n
		AddressStringDict[TAG_MAX] = n
		unlock(AddressStringLock)
		return n
	else
		return AddressStringDict[addr]
	end
	end

