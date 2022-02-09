

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


