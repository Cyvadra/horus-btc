
using ProgressMeter
using Dates
using ThreadsX

AddressStringDict = Dict{String,UInt32}()
const NUM_NOT_EXIST = UInt32(0)
const TAG_MAX = "maximum"
AddressStringDict_TAG_MAX = 930830585
AddressStringLock = Threads.SpinLock()


@info "$(now()) reading txt into memory..."
f = readlines("/mnt/data/bitcore/addr.latest.txt")
@info "$(now()) doing convertion..."
function lambdaAddressDict(x)
	tmpVal = split(x,'\t')
	return tmpVal[1], parse(UInt32, tmpVal[2])
	end
@info "$(now()) generating pairs..."
f = ThreadsX.map(x->lambdaAddressDict(x), f)
@info "$(now()) generate dict"
AddressStringDict = Dict{String,UInt32}(f)
f[TAG_MAX] = AddressStringDict_TAG_MAX
@info "$(now()) AddressService loaded!"
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

