using ThreadSafeDicts

AddressStringDict = ThreadSafeDict{String,UInt32}()
AddressStringDict["maximum"] = 1

AddressStringDict.enabled = false

tmpList = []
counter = 0
@showprogress for i in 1:1600:length(f)
	counter = i+1599
	tmpList = map(x->split(x,'\t'), f[i:counter])
	for s in tmpList
		AddressStringDict[s[1]] = parse(UInt32, s[2])
	end
end


