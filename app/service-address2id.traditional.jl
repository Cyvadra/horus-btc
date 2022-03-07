
using ProgressMeter

AddressStringDict = Dict{String,UInt32}()
AddressStringDict["maximum"] = 1

tmpList = []
counter = 0
_len = length(f)
s = ["asdf", "123"]
@showprogress for l in f
	s = split(l,'\t')
	AddressStringDict[s[1]] = parse(UInt32, s[2])
	end




