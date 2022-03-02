

	function batchTouch!(rng::UnitRange{Int})::Nothing
		coinPrice = FinanceDB.GetDerivativePriceWhen.(pairName, sumTs[rng[end]])
		# existing addresses
		concreteIndexes = rng[map(x->!x, sumTagNew[rng])]
		uniqueAddrIds   = unique(sumAddrId[concreteIndexes])
		tmpAmountIncomeDict  = Dict{UInt32, Float64}()
		tmpAmountExpenseDict = Dict{UInt32, Float64}()
		tmpTsInDict   = Dict{UInt32, Vector{Int32}}()
		tmpTsOutDict  = Dict{UInt32, Vector{Int32}}()
		for addrId in uniqueAddrIds
			tmpRng = findall(x->x==addrId, sumAddrId[concreteIndexes])
			tmpAmounts = sumAmount[concreteIndexes][tmpRng]
			tmpAmountIncomeDict[addrId]  = sum(tmpAmounts[tmpAmounts .> 0.0])
			tmpAmountExpenseDict[addrId] = sum(tmpAmounts[tmpAmounts .< 0.0])
			tmpTsInDict[addrId]  = sumTs[concreteIndexes][tmpRng][sumAmount[concreteIndexes][tmpRng] .> 0]
			tmpTsOutDict[addrId] = sumTs[concreteIndexes][tmpRng][sumAmount[concreteIndexes][tmpRng] .< 0]
		end
		for addrId in uniqueAddrIds
			tmpBalance = AddressService.GetFieldBalance(addrId)
			if tmpAmountExpenseDict[addrId] > 0
				AddressService.SetFieldDiffAmountExpenseTotal(pos, -tmpAmountExpenseDict[addrId])
				AddressService.SetFieldDiffNumTxOutTotal(pos, length(tmpTsOutDict[addrId]))
				AddressService.SetFieldTimestampLastPayed(pos, tmpTsOutDict[addrId][end])
				tmpPrice = FinanceDB.GetDerivativePriceWhen.( pairName,
						round(Int32, mean(tmpTsOutDict[addrId])) )
				AddressService.SetFieldDiffUsdtReceived4Output(pos, -tmpAmountExpenseDict[addrId] * tmpPrice)
				AddressService.SetFieldLastSellPrice(pos, tmpPrice)
			end
			if tmpAmountIncomeDict[addrId] > 0
				AddressService.SetFieldDiffAmountIncomeTotal(pos, tmpAmountIncomeDict[addrId])
				AddressService.SetFieldDiffNumTxInTotal(pos, length(tmpTsInDict[addrId]))
				AddressService.SetFieldTimestampLastReceived(pos, tmpTsInDict[addrId][end])
				tmpPrice = FinanceDB.GetDerivativePriceWhen.( pairName,
						round(Int32, mean(tmpTsInDict[addrId])) )
				AddressService.SetFieldDiffUsdtPayed4Input(pos, tmpAmountIncomeDict[addrId] * tmpPrice)
				if tmpBalance > 1e-9
					AddressService.SetFieldAveragePurchasePrice(pos,
						(tmpAmountIncomeDict[addrId] * tmpPrice + AddressService.GetFieldAveragePurchasePrice(pos) * tmpBalance) / (tmpBalance + tmpAmountIncomeDict[addrId]) )
				else
					AddressService.SetFieldAveragePurchasePrice(pos, tmpPrice)
				end
			end
			tsList = sort!(vcat(tmpTsInDict[addrId], tmpTsOutDict[addrId]))
			if tmpBalance < 0 && AddressService.GetFieldTimestampCreated(pos) > tsList[1]
				AddressService.SetFieldTimestampCreated(pos, tsList[1])
			end
			if AddressService.GetFieldTimestampLastActive(pos) < tsList[end]
				AddressService.SetFieldTimestampLastActive(pos, tsList[end])
			end
			AddressService.SetFieldDiffBalance(pos, tmpAmountIncomeDict[addrId]+tmpAmountExpenseDict[addrId])
			AddressService.SetFieldUsdtNetRealized(pos,
				 AddressService.GetFieldUsdtReceived4Output(pos) - AddressService.GetFieldUsdtPayed4Input(pos)
				 )
			AddressService.SetFieldUsdtNetUnrealized(pos,
				 ( coinPrice - AddressService.GetFieldAveragePurchasePrice(pos) )
				 * AddressService.GetFieldBalance(pos)
				 )
		end
		# new addresses
		newIndexes  = rng[sumTagNew[rng]]
		for _ind in newIndexes
			pos = sumAddrId[_ind]
			if !sumTagNew[_ind]
				throw("program incorrect!")
			end
			coinPrice = FinanceDB.GetDerivativePriceWhen(pairName, sumTs[_ind])
			coinUsdt  = abs(sumAmount[_ind]) * coinPrice
			if sumAmount[_ind] >= 0
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, sumAmount[_ind])
				AddressService.SetFieldAmountExpenseTotal(pos, 0.0)
				AddressService.SetFieldNumTxInTotal(pos, 1)
				AddressService.SetFieldNumTxOutTotal(pos, 0)
				AddressService.SetFieldUsdtPayed4Input(pos, coinUsdt)
				AddressService.SetFieldUsdtReceived4Output(pos, 0.0)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, 0.0)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			else
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, 0.0)
				AddressService.SetFieldAmountExpenseTotal(pos, abs(sumAmount[_ind]))
				AddressService.SetFieldNumTxInTotal(pos, 0)
				AddressService.SetFieldNumTxOutTotal(pos, 1)
				AddressService.SetFieldUsdtPayed4Input(pos, 0.0)
				AddressService.SetFieldUsdtReceived4Output(pos, coinUsdt)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, coinUsdt)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			end
		end
		return nothing
		end


