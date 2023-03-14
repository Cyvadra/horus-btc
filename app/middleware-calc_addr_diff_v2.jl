# include("./service-FinanceDB.jl");
# include("./service-transactions.jl");
# include("./service-block_timestamp.jl");

function InitAddressState(tmpId::UInt32, ts::Int32, tmpPrice::Float64)::Nothing
	AddressService.SetFieldTimestampCreated(tmpId, ts)
	AddressService.SetFieldAverageTradeIntervalSecs(tmpId, 3600)
	AddressService.SetFieldLastPurchasePrice(tmpId, tmpPrice)
	AddressService.SetFieldLastSellPrice(tmpId, tmpPrice)
	AddressService.SetFieldNumWinning(tmpId, 1)
	AddressService.SetFieldNumLossing(tmpId, 1)
	AddressService.SetFieldUsdtAmountWon(tmpId, 0.1)
	AddressService.SetFieldUsdtAmountLost(tmpId, 0.1)
	AddressService.SetFieldAverageMintTimestamp(ts)
	AddressService.SetFieldAverageSpentTimestamp(ts)
	return nothing
	end
function SubTouchAddressState(tmpId::UInt32, ts::Int32, tmpPrice::Float64)::Nothing
	AddressService.SetFieldDiffNumTxTotal(tmpId, 1)
	AddressService.SetFieldAverageTradeIntervalSecs(tmpId,
		round(Int32,
			( AddressService.GetFieldAverageTradeIntervalSecs(tmpId) * AddressService.GetFieldNumTxTotal(tmpId) + ( ts - AddressService.GetFieldTimestampLastActive(tmpId) ) ) / ( AddressService.GetFieldNumTxTotal(tmpId) + 1 )
		)
	)
	AddressService.SetFieldUsdtNetUnrealized(tmpId,
		AddressService.GetFieldBalance(tmpId) * (tmpPrice - AddressService.GetFieldAveragePurchasePrice(tmpId))
	)
	AddressService.SetFieldTimestampLastActive(tmpId, ts)
	return nothing
	end
function MergeBlock2AddressState(n::Int)::Nothing
	ids = collect(GetSeqBlockCoinsRange(n))
	tmpIds     = TableTx.GetFieldAddressId(ids)
	tmpAmounts = TableTx.GetFieldAmount(ids)
	coinsIn    = findall(x->x>=0.0, tmpAmounts)
	coinsOut   = findall(x->x<0.0, tmpAmounts)
	ts       = n |> BlockNum2Timestamp
	tmpPrice = GetPriceAtBlockN(n)
	for i in coinsIn
		tmpId = tmpIds[i]
		tmpAmount = tmpAmounts[i]
		if isNew(tmpId)
			InitAddressState(tmpId, ts, tmpPrice)
		elseif !isequal(ts, AddressService.GetFieldTimestampLastActive(tmpId))
			SubTouchAddressState(tmpId, ts, tmpPrice)
		end
		AddressService.SetFieldAverageMintTimestamp(tmpId,
			( AddressService.GetFieldAverageMintTimestamp(tmpId) * AddressService.GetFieldAmountIncomeTotal(tmpId) + ts * tmpAmount ) / ( AddressService.GetFieldAmountIncomeTotal(tmpId) + tmpAmount)
		)
		AddressService.SetFieldTimestampLastReceived(tmpId, ts)
		AddressService.SetFieldDiffAmountIncomeTotal(tmpId, tmpAmount)
		AddressService.SetFieldDiffNumTxInTotal(tmpId, 1)
		AddressService.SetFieldDiffUsdtPayed4Input(tmpId, tmpPrice * tmpAmount)
		AddressService.SetFieldLastPurchasePrice(tmpId, tmpPrice)
		AddressService.SetFieldAveragePurchasePrice(tmpId,
			AddressService.GetFieldUsdtPayed4Input(tmpId) /
			AddressService.GetFieldAmountIncomeTotal(tmpId)
			)
		AddressService.SetFieldUsdtNetRealized(tmpId,
			AddressService.GetFieldUsdtReceived4Output(tmpId) - AddressService.GetFieldUsdtPayed4Input(tmpId)
			)
		AddressService.SetFieldBalance(tmpId,
			AddressService.GetFieldAmountIncomeTotal(tmpId) - AddressService.GetFieldAmountExpenseTotal(tmpId)
			)
	end
	for i in coinsOut
		tmpId = tmpIds[i]
		tmpAmount = abs(tmpAmounts[i])
		if isNew(tmpId)
			InitAddressState(tmpId, ts, tmpPrice)
		elseif !isequal(ts, AddressService.GetFieldTimestampLastActive(tmpId))
			SubTouchAddressState(tmpId, ts, tmpPrice)
		end
		AddressService.SetFieldAverageSpentTimestamp(tmpId,
			( AddressService.GetFieldAverageSpentTimestamp(tmpId) * AddressService.GetFieldAmountExpenseTotal(tmpId) + ts * tmpAmount ) / ( AddressService.GetFieldAmountExpenseTotal(tmpId) + tmpAmount)
		)
		# judge whether winning
		if tmpPrice >= AddressService.GetFieldLastPurchasePrice(tmpId)
			if !isequal(ts, AddressService.GetFieldTimestampLastPayed(tmpId))
				AddressService.SetFieldDiffNumWinning(tmpId, 1)
			end
			AddressService.SetFieldDiffUsdtAmountWon(tmpId,
				(tmpPrice - AddressService.GetFieldLastPurchasePrice(tmpId)) * tmpAmount
			)
		else # if loss
			if !isequal(ts, AddressService.GetFieldTimestampLastPayed(tmpId))
				AddressService.SetFieldDiffNumLossing(tmpId, 1)
			end
			AddressService.SetFieldDiffUsdtAmountLost(tmpId,
				(AddressService.GetFieldLastPurchasePrice(tmpId) - tmpPrice) * tmpAmount
			)
		end
		AddressService.SetFieldRateWinning(tmpId,
			AddressService.GetFieldNumWinning(tmpId) / ( AddressService.GetFieldNumWinning(tmpId) + AddressService.GetFieldNumLossing(tmpId) )
		)
		AddressService.SetFieldTimestampLastPayed(tmpId, ts)
		AddressService.SetFieldDiffAmountExpenseTotal(tmpId, tmpAmount)
		AddressService.SetFieldDiffNumTxOutTotal(tmpId, 1)
		AddressService.SetFieldDiffUsdtReceived4Output(tmpId, tmpPrice * tmpAmount)
		AddressService.SetFieldLastSellPrice(tmpId, tmpPrice)
		AddressService.SetFieldUsdtNetRealized(tmpId,
			AddressService.GetFieldUsdtReceived4Output(tmpId) - AddressService.GetFieldUsdtPayed4Input(tmpId)
			)
		AddressService.SetFieldBalance(tmpId,
			AddressService.GetFieldAmountIncomeTotal(tmpId) - AddressService.GetFieldAmountExpenseTotal(tmpId)
			)
	end
	return nothing
	end



BlockPriceDict = Dict{Int, Float32}()
function SyncBlockPriceDict(fromN, toN)::Nothing
	for h in fromN:toN
		BlockPriceDict[h] = h |> BlockNum2Timestamp |> GetBTCPriceWhen
	end
	return nothing
	end
function GetPriceAtBlockN(height)::Float64
	if !haskey(BlockPriceDict, height)
		BlockPriceDict[height] = height |> BlockNum2Timestamp |> GetBTCPriceWhen
	end
	return BlockPriceDict[height]
	end
