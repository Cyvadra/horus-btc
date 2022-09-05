
# Pretreatment ==> listXXX
uniqueAddrs  = ThreadsX.unique(sumAddrId)
_len         = length(uniqueAddrs)
listStartPos = zeros(Int, _len)
listEndPos   = collect(1:_len)
listAddrId   = zeros(UInt32, _len)
prog = Progress(length(uniqueAddrs)-1)
listStartPos[1]   = findfirst(x->x==uniqueAddrs[1], sumAddrId)
listEndPos[1]     = findnext(x->x!==uniqueAddrs[1], sumAddrId, 1)
listAddrId[1]     = uniqueAddrs[1]
Threads.@threads for i in 2:_len
	tmpStartPos     = findnext(
		x->x==uniqueAddrs[i],
		sumAddrId,
		listEndPos[i-1]
	)
	listStartPos[i] = tmpStartPos
	listEndPos[i]   = findnext(x->x!==uniqueAddrs[i], sumAddrId, tmpStartPos) - 1
	listAddrId[i]   = uniqueAddrs[i]
	next!(prog)
end

# save data 
	JLD2.save(dataFolder*"listPositionsForParallel.jld2",
		"listStartPos", listStartPos,
		"listEndPos", listEndPos,
		"listAddrId", listAddrId,
		)
