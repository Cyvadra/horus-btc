

# Jan, 2021
	mutable struct PeriodStat
		timestamp::Int32
	# CellAddressActivity # T3 
		numNew::Int32
		numChargePercentAbove50::Int32
		numChargePercentAbove75::Int32
		numWithdrawPercentAbove50::Int32
		numWithdrawPercentAbove75::Int32
		numSending::Int32
		numReceiving::Int32
		numRecentM1Sending::Int32
		numRecentM1Receiving::Int32
		numTotalActive::Int32
	# CellAddressSupply # T1
		# of all inputs, how much balance did they have before
		supplierBalanceMicro::Int32
		supplierBalance0001::Int32
		supplierBalance001::Int32
		supplierBalance01::Int32
		supplierBalance1::Int32
		supplierBalance10::Int32
		supplierBalance100::Int32
		supplierBalance1k::Int32
		supplierBalance10k::Int32
		supplierBalance50k::Int32
		supplierBalanceMore::Int32
		supplierBalanceMicroAmount::Float64
		supplierBalance0001Amount::Float64
		supplierBalance001Amount::Float64
		supplierBalance01Amount::Float64
		supplierBalance1Amount::Float64
		supplierBalance10Amount::Float64
		supplierBalance100Amount::Float64
		supplierBalance1kAmount::Float64
		supplierBalance10kAmount::Float64
		supplierBalance50kAmount::Float64
		supplierBalanceMoreAmount::Float64
		wakeupAmountM1Sending::Float64
		wakeupAmountM1Receiving::Float64
		wakeupAmountM3Sending::Float64
		wakeupAmountM3Receiving::Float64
		# those who transferred 75%+ of balance
		supplierBreakMicro::Int32
		supplierBreak0001::Int32
		supplierBreak001::Int32
		supplierBreak01::Int32
		supplierBreak1::Int32
		supplierBreak10::Int32
		supplierBreak100::Int32
		supplierBreak1k::Int32
		supplierBreak10k::Int32
		supplierBreak50k::Int32
		supplierBreakMore::Int32
	# CellAddressBalanceDiff # T2
		numBalanceNonZero::Int32 # not implemented
		numBalanceDiffMicro::Int32
		numBalanceDiff0001::Int32
		numBalanceDiff001::Int32
		numBalanceDiff01::Int32
		numBalanceDiff1::Int32
		numBalanceDiff10::Int32
		numBalanceDiff100::Int32
		numBalanceDiff1k::Int32
		numBalanceDiff10k::Int32
		numBalanceDiff50k::Int32
	end



# Core Handler function
	function lambdaCalcActivity(stat::Base.RefValue, addrId::UInt32, amount::Float64, flagNew::Bool)::Nothing
		if amount > 0
			stat.x.numReceiving += 1
			if flagNew
				stat.x.numNew += 1
				stat.x.numChargePercentAbove50 += 1
				stat.x.numChargePercentAbove75 += 1
			else
				if AddressState[addrId].Balance <= 3 * amount
					stat.x.numChargePercentAbove75 += 1
					if AddressState[addrId].Balance <= amount
						stat.x.numChargePercentAbove50 += 1
					end
				end
			end
			if !flagNew
				if stat.x.timestamp - AddressState[addrId].TimestampLastActive <= seconds.Month
					stat.x.numRecentM1Receiving += 1
				else
					stat.x.wakeupAmountM1Receiving += amount
					if stat.x.timestamp - AddressState[addrId].TimestampLastActive > 3*seconds.Month
						stat.x.wakeupAmountM3Receiving += amount
					end
				end
			end
		elseif amount < 0
			stat.x.numSending += 1
			if !flagNew
				if stat.x.timestamp - AddressState[addrId].TimestampLastActive <= seconds.Month
					stat.x.numRecentM1Sending += 1
				else
					stat.x.wakeupAmountM1Sending -= amount
					if stat.x.timestamp - AddressState[addrId].TimestampLastActive > 3*seconds.Month
						stat.x.wakeupAmountM3Sending -= amount
					end
				end
				if -amount >= 0.5*AddressState[addrId].Balance
					stat.x.numWithdrawPercentAbove50 += 1
					if -amount >= 0.75*AddressState[addrId].Balance
						stat.x.numWithdrawPercentAbove75 += 1
					end
				end
			end
		end
		return nothing
		end
	function lambdaCalcNonZero(targetVal::Base.RefValue{Int32}, balanceBefore::Float64, balanceAfter::Float64)::Nothing		
		if balanceBefore < 1e-6 && balanceAfter >= 1e-6
			targetVal.x += 1
		elseif balanceBefore > 1e-6 && balanceAfter < 1e-6
			targetVal.x -= 1
		end
		return nothing
		end
	function lambdaCalcBalanceDiff(targetVal::Base.RefValue{Int32}, balanceBefore::Float64, balanceAfter::Float64, rangeLeft::Float64, rangeRight::Float64)::Nothing
		if rangeLeft <= balanceAfter < rangeRight && 
			!(rangeLeft <= balanceBefore < rangeRight)
			targetVal.x += 1
		elseif rangeLeft <= balanceBefore < rangeRight && 
			!(rangeLeft <= balanceAfter < rangeRight)
			targetVal.x -= 1
		end
		return nothing
		end
	function lambdaCalcBalanceNew(targetStat::Base.RefValue{PeriodStat}, amount::Float64)::Nothing
		if 1e-6 < amount
			targetStat.x.numBalanceNonZero += 1
			if amount <= 1e-3
				targetStat.x.numBalanceDiffMicro += 1
			end
		end
		if 1e-3 < amount <= 1e-2
			targetStat.x.numBalanceDiff0001 += 1
		elseif 1e-2 < amount <= 1e-1
			targetStat.x.numBalanceDiff001 += 1
		elseif 1e-1 < amount <= 1.0
			targetStat.x.numBalanceDiff01 += 1
		elseif 1.0 < amount <= 10.0
			targetStat.x.numBalanceDiff1 += 1
		elseif 10.0 < amount <= 100.0
			targetStat.x.numBalanceDiff10 += 1
		elseif 100.0 < amount <= 1e3
			targetStat.x.numBalanceDiff100 += 1
		elseif 1e3 < amount <= 1e4
			targetStat.x.numBalanceDiff1k += 1
		elseif 1e4 < amount <= 5e4
			targetStat.x.numBalanceDiff10k += 1
		elseif 5e4 < amount
			targetStat.x.numBalanceDiff50k += 1
		end
		return nothing
		end
	function lambdaCalcSupplier(stat::Base.RefValue, balanceBefore::Float64, amount::Float64)::Nothing
		breakLimit = 0.8
		rangeLeft, rangeRight = 0.0, 0.001
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalanceMicro += 1
			stat.x.supplierBalanceMicroAmount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreakMicro += 1
			end
		end
		rangeLeft, rangeRight = 1e-3, 1e-2
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance0001 += 1
			stat.x.supplierBalance0001Amount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak0001 += 1
			end
		end
		rangeLeft, rangeRight = 1e-2, 1e-1
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance001 += 1
			stat.x.supplierBalance001Amount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak001 += 1
			end
		end
		rangeLeft, rangeRight = 1e-1, 1e0
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance01 += 1
			stat.x.supplierBalance01Amount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak01 += 1
			end
		end
		rangeLeft, rangeRight = 1e0, 1e1
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance1 += 1
			stat.x.supplierBalance1Amount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak1 += 1
			end
		end
		rangeLeft, rangeRight = 1e1, 1e2
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance10 += 1
			stat.x.supplierBalance10Amount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak10 += 1
			end
		end
		rangeLeft, rangeRight = 1e2, 1e3
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance100 += 1
			stat.x.supplierBalance100Amount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak100 += 1
			end
		end
		rangeLeft, rangeRight = 1e3, 1e4
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance1k += 1
			stat.x.supplierBalance1kAmount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak1k += 1
			end
		end
		rangeLeft, rangeRight = 1e4, 1e5
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance10k += 1
			stat.x.supplierBalance10kAmount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak10k += 1
			end
		end
		rangeLeft, rangeRight = 1e5, 5e5
		if rangeLeft < balanceBefore <= rangeRight
			stat.x.supplierBalance50k += 1
			stat.x.supplierBalance50kAmount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreak50k += 1
			end
		end
		rangeLeft = 5e5
		if rangeLeft < balanceBefore
			stat.x.supplierBalanceMore += 1
			stat.x.supplierBalanceMoreAmount += amount
			if amount / balanceBefore > breakLimit
				stat.x.supplierBreakMore += 1
			end
		end
		return nothing
		end
	function CalcPeriod(ts::Int32, collections::Vector{Pair{UInt32,Float64}})::PeriodStat
		stat = deepcopy(tplPeriodStat)
		stat.timestamp = ts # start
		stat.numTotalActive = length(collections)
		for p in collections
			addrId, amount = p[1], p[2]
			flagNew = !haskey(AddressState, addrId)
		# CellAddressActivity # T3
			lambdaCalcActivity(Ref(stat), addrId, amount, flagNew)
		# CellAddressSupply # T1
			if !flagNew && amount < 0
				balanceBefore = AddressState[addrId].Balance
				lambdaCalcSupplier(Ref(stat), balanceBefore, -amount)
			end
		# CellAddressBalanceDiff # T2
			if !flagNew
				balanceBefore = AddressState[addrId].Balance
				balanceAfter  = balanceBefore + amount
				lambdaCalcNonZero(Ref(stat.numBalanceNonZero),
					balanceBefore, balanceAfter)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff0001),
					balanceBefore, balanceAfter, 1e-3, 1e-6)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff001),
					balanceBefore, balanceAfter, 0.01, 0.1)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff01),
					balanceBefore, balanceAfter, 0.1, 1.0)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff1),
					balanceBefore, balanceAfter, 1.0, 10.0)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff10),
					balanceBefore, balanceAfter, 10.0, 100.0)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff100),
					balanceBefore, balanceAfter, 100.0, 1000.0)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff1k),
					balanceBefore, balanceAfter, 1000.0, 10000.0)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff10k),
					balanceBefore, balanceAfter, 1e4, 5e4)
				lambdaCalcBalanceDiff(Ref(stat.numBalanceDiff50k),
					balanceBefore, balanceAfter, 5e4, Inf)
			else
				lambdaCalcBalanceNew(Ref(stat), amount)
			end
		end
		return stat
		end

	function ProcessPeriods!(fromDate::DateTime, toDate::DateTime, timeStep::T, results::Base.RefValue{Vector{PeriodStat}})::Vector{PeriodStat} where T <: Dates.TimePeriod # threaded inside
		period   = SelectPeriod(fromDate, toDate, TxRowsDF.Timestamp)
		posStart = period[1]
		posEnd   = period[end]
		# demo loop
		prevDonePos  = posStart - 1
		prevUndoneDt = fromDate
		prog         = Progress(posEnd-posStart)
		while prevUndoneDt < toDate
			loopStart  = prevDonePos + 1
			loopEnd    = findnext(x->
				x >= dt2unix( prevUndoneDt + timeStep ),
				TxRowsDF.Timestamp, loopStart
			) - 1 # for performance
			AddressDiff = deepcopy(AddressDiffTpl)
			# sum into AddressDiff
			for i in loopStart:loopEnd # do not multi-thread
				if !haskey(AddressDiff, TxRowsDF[i,:AddressId])
					AddressDiff[TxRowsDF[i,:AddressId]]  = TxRowsDF[i,:Amount]
				else
					AddressDiff[TxRowsDF[i,:AddressId]] += TxRowsDF[i,:Amount]
				end
			end
			# call method CalcPeriod
			statUnit = CalcPeriod(TxRowsDF[loopStart, :Timestamp], collect(AddressDiff))
			push!(results.x, statUnit)
			empty!(AddressDiff)
			# update AddressStatistics
			for i in loopStart:loopEnd
				addrId, amount, ts = TxRowsDF[i,:]
				touch!(addrId, ts, amount)
			end
			# update vars
			prevDonePos = loopEnd
			prevUndoneDt += timeStep
			next!(prog;step=prevDonePos-loopStart+1)
		end
		return results.x
		end


# working done

# Smooth Timestamp (once)
	# @time Smooth!(TxRowsDF.Timestamp)
	# @time Smooth!(TxStateDF.Timestamp)



