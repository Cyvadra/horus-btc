
using ProgressMeter

nextPosRef = 1
currentPos = 1
addrId = df.AddressId[currentPos]
endPos = findnext(x->x!==addrId, df.AddressId, nextPosRef) - 1

prog = ProgressMeter.Progress(nrow(df); barlen=36, color=:blue)
while !isnothing(endPos)
	txs    = currentPos:endPos
	# ...
	next!(prog, length(txs))
	currentPos = endPos + 1
	addrId = df.AddressId[currentPos]
	endPos = findnext(x->x!==addrId, df.AddressId, nextPosRef) - 1
	end






