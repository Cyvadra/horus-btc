using MmapDB

MmapDB.Init(folderTransactions)

mutable struct cacheTx
	addressId::UInt32
	blockNum::Int32
	balanceBeforeBlock::Float64
	balanceAfterBlock::Float64
	mintHeight::Int32
	spentHeight::Int32
	amount::Float64
	timestamp::UInt32
	end

TableTx = MmapDB.GenerateCode(cacheTx)
TableTx.Open(true)

function txLocateBlock(n::Int, tmpCounter::Int=1024)
	n = Int32(n)
	currentPos = TableTx.GetFieldBlockNum(tmpCounter)
	tmpStep = 65535
	lastSign = currentPos < n
	# enlarge number
	while currentPos < n
		tmpCounter += tmpStep
		currentPos = TableTx.GetFieldBlockNum(tmpCounter)
	end
	# locate position
	while currentPos < n || currentPos > n
		if !isequal(lastSign, currentPos < n)
			tmpStep = max(tmpStep >> 1, 1)
			lastSign = currentPos < n
		end
		if tmpCounter <= tmpStep || tmpCounter >= TableTx.Config["lastNewID"]
			tmpStep = max(tmpCounter >> 1, 1)
		end
		if currentPos > n
			tmpCounter -= tmpStep
			currentPos = TableTx.GetFieldBlockNum(tmpCounter)
		else
			tmpCounter += tmpStep
			currentPos = TableTx.GetFieldBlockNum(tmpCounter)
		end
	end
	# find first
	tmpCounter = max(tmpCounter-tmpStep, 1)
	TableTx.Findnext(x->x>=n, :blockNum, tmpCounter)
	end

function GetSeqBlockCoinsRange(n::Int)
	a = txLocateBlock(n)
	b = txLocateBlock(n+1, a) - 1
	return a:b
	end








