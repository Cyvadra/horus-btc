module AddressService

	using ThreadSafeDicts

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
		Balance::Float64 # btc
		end
	AddressState  = ThreadSafeDict{UInt32,AddressStatistics}()

	function EnableSpinLock()
		AddressState.enabled = true
		end
	function DisableSpinLock()
		AddressState.enabled = false
		end

	function hasAddress(addrId::UInt32)::Bool
		return haskey(AddressState, addrId)
		end
	function isNew(addrId::UInt32)::Bool
		return !haskey(AddressState, addrId)
		end


	function SetAddress(addrId::UInt32, stat::AddressStatistics)::Nothing
		AddressState[addrId] = stat
		return nothing
		end

	function GetStatRef(addrId::UInt32)::Base.RefValue{AddressStatistics}
		return Ref(AddressState[addrId])
		end

	function GetAddrBalance(addrId::UInt32)::Float64
		return AddressState[addrId].Balance
		end
	function GetAddrBalanceAbs(addrId::UInt32)::Float64
		return abs(AddressState[addrId].Balance)
		end
	function GetListAddrBalance(addrIds::Vector{UInt32})::Vector{Float64}
		map(x->AddressState[x].Balance, addrIds)
		end
	function GetListAddrBalanceAbs(addrIds::Vector{UInt32})::Vector{Float64}
		map(x->abs(AddressState[x].Balance), addrIds)
		end
	function GetAveragePurchasePrice(addrId::UInt32)::Float32
		return AddressState[addrId].AveragePurchasePrice
		end
	function GetListTimestampLastPayed(addrIds::Vector{UInt32})::Vector{Int32}
		map(x->AddressState[x].TimestampLastPayed, addrIds)
		end
	function GetListTimestampLastReceived(addrIds::Vector{UInt32})::Vector{Int32}
		map(x->AddressState[x].TimestampLastReceived, addrIds)
		end



	mutable struct AddressSnapshot
		# for statistics
		BalanceVector::Vector{Float64}
		TsActiveVector::Vector{Int32}
		# in profit
		NumInProfitRealized::Int64
		NumInProfitUnrealized::Int64
		AmountInProfitRealized::Float64
		AmountInProfitUnrealized::Float64
		# in loss
		NumInLossRealized::Int64
		NumInLossUnrealized::Int64
		AmountInLossRealized::Float64
		AmountInLossUnrealized::Float64
		end
	tplAddressSnapshot = AddressSnapshot(Float64[], Int32[], zeros(length(AddressSnapshot.types)-2)...)
	function TakeSnapshot()::AddressSnapshot
		ret = deepcopy(tplAddressSnapshot)
		for p in AddressState
			push!(ret.BalanceVector, p[2].Balance)
			push!(ret.TsActiveVector, p[2].TimestampLastActive)
			if p[2].UsdtNetRealized > 0
				ret.NumInProfitRealized += 1
				ret.AmountInProfitRealized += p[2].UsdtNetRealized
			elseif p[2].UsdtNetRealized < 0
				ret.NumInLossRealized += 1
				ret.AmountInLossRealized -= p[2].UsdtNetRealized
			end
			if p[2].UsdtNetUnrealized > 0
				ret.NumInProfitUnrealized += 1
				ret.AmountInProfitUnrealized += p[2].UsdtNetUnrealized
			elseif p[2].UsdtNetUnrealized < 0
				ret.NumInLossUnrealized += 1
				ret.AmountInLossUnrealized -= p[2].UsdtNetUnrealized
			end
		end
		return ret
		end



















end