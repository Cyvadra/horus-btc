
using ProgressMeter


mutable struct AddressStatistics
	# timestamp
	TimestampCreated::Int32
	TimestampLastActive::Int32
	TimestampLastReceived::Int32
	TimestampLastPayed::Int32
	# amount
	AmountIncomeTotal::Float64
	AmountExpenseTotal::Float64
	# statistics
	NumTxInTotal::Int32
	NumTxOutTotal::Int32
	# relevant usdt amount
	UsdtPayed4Input::Float64
	UsdtReceived4Output::Float64
	AveragePurchasePrice::Float32
	LastSellPrice::Float32
	# calculated extra
	UsdtNetRealized::Float64
	UsdtNetUnrealized::Float64
	Balance::Float64
	end
function GenerateState(addrId::UInt32, startN::Int, endN::Int)::AddressStatistics
	mintTags  = map(x->x>0.0, df.Amount[startN:endN])
	spentTags = map(x->x<0.0, df.Amount[startN:endN])
	ret   = AddressStatistics(
		min(df.Timestamp[startN:endN]...), # TimestampCreated Int32
		max(df.Timestamp[startN:endN]...), # TimestampLastActive Int32
		df.Timestamp[
			startN - 1 + findlast(x->x, mintTags)
		], # TimestampLastReceived Int32
		df.Timestamp[
			startN - 1 + findlast(x->x, spentTags)
		], # TimestampLastPayed Int32
		df.Amount[startN:endN][mintTags] |> sum, # AmountIncomeTotal Float64
		df.Amount[startN:endN][spentTags] |> sum |> abs, # AmountExpenseTotal Float64
		sum(mintTags), # NumTxInTotal Int32
		sum(spentTags), # NumTxOutTotal Int32
		0, # UsdtPayed4Input Float64
		0, # UsdtReceived4Output Float64
		0, # AveragePurchasePrice Float32
		0, # LastSellPrice Float32
		0, # UsdtNetRealized Float64
		0, # UsdtNetUnrealized Float64
		0 , # Balance Float64
	)
	return ret
	end


















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






