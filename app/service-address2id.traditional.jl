
using ProgressMeter
using Dates

AddressStringDict = Dict{String,UInt32}()
const NUM_NOT_EXIST = UInt32(0)
const TAG_MAX = "maximum"
AddressStringDict[TAG_MAX] = 930830585
AddressStringLock = Threads.SpinLock()


@show now()
f = open("/mnt/data/bitcore/addr.latest.txt", "r")
l = readline(f)
while !isnothing(l)
	s = split(l,'\t')
	AddressStringDict[s[1]] = parse(UInt32, s[2])
	l = readline(f)
	end
@show now()
close(f)
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

