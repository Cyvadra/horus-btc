module AddressService

	using Mmap; using Mmap:mmap
	using JLD2;

	Config = Dict{String,Any}(
			"dataFolder"  => "/mnt/data/AddressServiceMemory/",
			"dataLength"  => round(Int, 1e9),
		)

	mutable struct AddressStatisticsReadOnly
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
	AddressStatisticsDict = Dict{Symbol, Vector}()
	_syms  = fieldnames(AddressStatisticsReadOnly)
	_types = Vector{DataType}(collect(AddressStatisticsReadOnly.types))
	@assert all(isprimitivetype.(_types))


	function Open(dataFolder::String=Config["dataFolder"])::Nothing
		# check params
		dataFolder[end] !== '/' ? dataFolder = dataFolder*"/" : nothing
		isdir(dataFolder) || mkdir(dataFolder)
		for i in 1:length(_syms)
			AddressStatisticsDict[_syms[i]] = JLD2.load(
				dataFolder * string(_syms[i]) * ".jld2",
			)[string(_syms[i])]
		end
		return nothing
		end
	function OpenMmap(dataFolder::String=Config["dataFolder"], numRows::Int=Config["dataLength"])::Nothing
		# check params
		dataFolder[end] !== '/' ? dataFolder = dataFolder*"/" : nothing
		isdir(dataFolder) || mkdir(dataFolder)
		for i in 1:length(_types)
			f = open(dataFolder*string(_syms[i])*".bin", "r")
			AddressStatisticsDict[_syms[i]] = deepcopy(mmap(
				f, Vector{_types[i]}, numRows; grow=false
				))
			close(f)
		end
		return nothing
		end
	function Create(numRows::Int=Config["dataLength"])::Nothing
		for i in 1:length(_types)
			AddressStatisticsDict[_syms[i]] = zeros(
				_types[i], numRows)
		end
		return nothing
		end
	function SyncToDisk!(dataFolder::String=Config["dataFolder"])::Nothing
		# check params
		dataFolder[end] !== '/' ? dataFolder = dataFolder*"/" : nothing
		isdir(dataFolder) || mkdir(dataFolder)
		numRows = length(AddressStatisticsDict[_syms[1]])
		for i in 1:length(_syms)
			JLD2.save(
				dataFolder * string(_syms[i]) * ".jld2",
				string(_syms[i]),
				AddressStatisticsDict[_syms[i]]
			)
			@info "Done saving $(dataFolder*string(_syms[i])).jld2"
		end
		return nothing
		end


	function GetField(sym::Symbol, i::UInt32)
		return AddressStatisticsDict[sym][i]
		end
	function GetField(sym::Symbol, ids::Vector{UInt32})::Vector
		return AddressStatisticsDict[sym][ids]
		end
	function SetField(sym::Symbol, i::UInt32, v)::Nothing
		AddressStatisticsDict[sym][i] = v
		return nothing
		end
	function SetFieldDiff(sym::Symbol, i::UInt32, v)::Nothing
		AddressStatisticsDict[sym][i] += v
		return nothing
		end

	function GetRow(i::UInt32)::AddressStatisticsReadOnly
		AddressStatisticsReadOnly(
			AddressStatisticsDict[:TimestampCreated][i],
			AddressStatisticsDict[:TimestampLastActive][i],
			AddressStatisticsDict[:TimestampLastReceived][i],
			AddressStatisticsDict[:TimestampLastPayed][i],
			AddressStatisticsDict[:AmountIncomeTotal][i],
			AddressStatisticsDict[:AmountExpenseTotal][i],
			AddressStatisticsDict[:NumTxInTotal][i],
			AddressStatisticsDict[:NumTxOutTotal][i],
			AddressStatisticsDict[:UsdtPayed4Input][i],
			AddressStatisticsDict[:UsdtReceived4Output][i],
			AddressStatisticsDict[:AveragePurchasePrice][i],
			AddressStatisticsDict[:LastSellPrice][i],
			AddressStatisticsDict[:UsdtNetRealized][i],
			AddressStatisticsDict[:UsdtNetUnrealized][i],
			AddressStatisticsDict[:Balance][i],
			)
		end
	function SetRow(i::UInt32, TimestampCreated, TimestampLastActive, TimestampLastReceived, TimestampLastPayed, AmountIncomeTotal, AmountExpenseTotal, NumTxInTotal, NumTxOutTotal, UsdtPayed4Input, UsdtReceived4Output, AveragePurchasePrice, LastSellPrice, UsdtNetRealized, UsdtNetUnrealized, Balance)::Nothing
		AddressStatisticsDict[:TimestampCreated][i] = TimestampCreated
		AddressStatisticsDict[:TimestampLastActive][i] = TimestampLastActive
		AddressStatisticsDict[:TimestampLastReceived][i] = TimestampLastReceived
		AddressStatisticsDict[:TimestampLastPayed][i] = TimestampLastPayed
		AddressStatisticsDict[:AmountIncomeTotal][i] = AmountIncomeTotal
		AddressStatisticsDict[:AmountExpenseTotal][i] = AmountExpenseTotal
		AddressStatisticsDict[:NumTxInTotal][i] = NumTxInTotal
		AddressStatisticsDict[:NumTxOutTotal][i] = NumTxOutTotal
		AddressStatisticsDict[:UsdtPayed4Input][i] = UsdtPayed4Input
		AddressStatisticsDict[:UsdtReceived4Output][i] = UsdtReceived4Output
		AddressStatisticsDict[:AveragePurchasePrice][i] = AveragePurchasePrice
		AddressStatisticsDict[:LastSellPrice][i] = LastSellPrice
		AddressStatisticsDict[:UsdtNetRealized][i] = UsdtNetRealized
		AddressStatisticsDict[:UsdtNetUnrealized][i] = UsdtNetUnrealized
		AddressStatisticsDict[:Balance][i] = Balance
		return nothing
		end
	function SetRow(i, v)::Nothing
		AddressStatisticsDict[:TimestampCreated][i] = v.TimestampCreated
		AddressStatisticsDict[:TimestampLastActive][i] = v.TimestampLastActive
		AddressStatisticsDict[:TimestampLastReceived][i] = v.TimestampLastReceived
		AddressStatisticsDict[:TimestampLastPayed][i] = v.TimestampLastPayed
		AddressStatisticsDict[:AmountIncomeTotal][i] = v.AmountIncomeTotal
		AddressStatisticsDict[:AmountExpenseTotal][i] = v.AmountExpenseTotal
		AddressStatisticsDict[:NumTxInTotal][i] = v.NumTxInTotal
		AddressStatisticsDict[:NumTxOutTotal][i] = v.NumTxOutTotal
		AddressStatisticsDict[:UsdtPayed4Input][i] = v.UsdtPayed4Input
		AddressStatisticsDict[:UsdtReceived4Output][i] = v.UsdtReceived4Output
		AddressStatisticsDict[:AveragePurchasePrice][i] = v.AveragePurchasePrice
		AddressStatisticsDict[:LastSellPrice][i] = v.LastSellPrice
		AddressStatisticsDict[:UsdtNetRealized][i] = v.UsdtNetRealized
		AddressStatisticsDict[:UsdtNetUnrealized][i] = v.UsdtNetUnrealized
		AddressStatisticsDict[:Balance][i] = v.Balance
		return nothing
		end

	function isNew(i::UInt32)::Bool
		return iszero(AddressStatisticsDict[:TimestampCreated][i])
		end
	function isNew(ids::Vector{UInt32})::Vector{Bool}
		return iszero.(AddressStatisticsDict[:TimestampCreated][ids])
		end


	# Generated methods GetFieldXXX
	function GetFieldTimestampCreated(i::T)::Int32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:TimestampCreated][i]
		end
	function GetFieldTimestampLastActive(i::T)::Int32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:TimestampLastActive][i]
		end
	function GetFieldTimestampLastReceived(i::T)::Int32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:TimestampLastReceived][i]
		end
	function GetFieldTimestampLastPayed(i::T)::Int32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:TimestampLastPayed][i]
		end
	function GetFieldAmountIncomeTotal(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:AmountIncomeTotal][i]
		end
	function GetFieldAmountExpenseTotal(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:AmountExpenseTotal][i]
		end
	function GetFieldNumTxInTotal(i::T)::Int32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:NumTxInTotal][i]
		end
	function GetFieldNumTxOutTotal(i::T)::Int32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:NumTxOutTotal][i]
		end
	function GetFieldUsdtPayed4Input(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:UsdtPayed4Input][i]
		end
	function GetFieldUsdtReceived4Output(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:UsdtReceived4Output][i]
		end
	function GetFieldAveragePurchasePrice(i::T)::Float32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:AveragePurchasePrice][i]
		end
	function GetFieldLastSellPrice(i::T)::Float32 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:LastSellPrice][i]
		end
	function GetFieldUsdtNetRealized(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:UsdtNetRealized][i]
		end
	function GetFieldUsdtNetUnrealized(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:UsdtNetUnrealized][i]
		end
	function GetFieldBalance(i::T)::Float64 where T <: Union{UInt32, Vector{UInt32}}
		return AddressStatisticsDict[:Balance][i]
		end


	# Generated methods SetFieldXXX
	function SetFieldTimestampCreated(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampCreated][i] = v
		return nothing
		end
	function SetFieldTimestampLastActive(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampLastActive][i] = v
		return nothing
		end
	function SetFieldTimestampLastReceived(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampLastReceived][i] = v
		return nothing
		end
	function SetFieldTimestampLastPayed(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampLastPayed][i] = v
		return nothing
		end
	function SetFieldAmountIncomeTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:AmountIncomeTotal][i] = v
		return nothing
		end
	function SetFieldAmountExpenseTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:AmountExpenseTotal][i] = v
		return nothing
		end
	function SetFieldNumTxInTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:NumTxInTotal][i] = v
		return nothing
		end
	function SetFieldNumTxOutTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:NumTxOutTotal][i] = v
		return nothing
		end
	function SetFieldUsdtPayed4Input(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtPayed4Input][i] = v
		return nothing
		end
	function SetFieldUsdtReceived4Output(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtReceived4Output][i] = v
		return nothing
		end
	function SetFieldAveragePurchasePrice(i::UInt32, v)::Nothing
		AddressStatisticsDict[:AveragePurchasePrice][i] = v
		return nothing
		end
	function SetFieldLastSellPrice(i::UInt32, v)::Nothing
		AddressStatisticsDict[:LastSellPrice][i] = v
		return nothing
		end
	function SetFieldUsdtNetRealized(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtNetRealized][i] = v
		return nothing
		end
	function SetFieldUsdtNetUnrealized(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtNetUnrealized][i] = v
		return nothing
		end
	function SetFieldBalance(i::UInt32, v)::Nothing
		AddressStatisticsDict[:Balance][i] = v
		return nothing
		end

	# Generated methods SetFieldDiffXXX
	function SetFieldDiffTimestampCreated(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampCreated][i] += v
		return nothing
		end
	function SetFieldDiffTimestampLastActive(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampLastActive][i] += v
		return nothing
		end
	function SetFieldDiffTimestampLastReceived(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampLastReceived][i] += v
		return nothing
		end
	function SetFieldDiffTimestampLastPayed(i::UInt32, v)::Nothing
		AddressStatisticsDict[:TimestampLastPayed][i] += v
		return nothing
		end
	function SetFieldDiffAmountIncomeTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:AmountIncomeTotal][i] += v
		return nothing
		end
	function SetFieldDiffAmountExpenseTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:AmountExpenseTotal][i] += v
		return nothing
		end
	function SetFieldDiffNumTxInTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:NumTxInTotal][i] += v
		return nothing
		end
	function SetFieldDiffNumTxOutTotal(i::UInt32, v)::Nothing
		AddressStatisticsDict[:NumTxOutTotal][i] += v
		return nothing
		end
	function SetFieldDiffUsdtPayed4Input(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtPayed4Input][i] += v
		return nothing
		end
	function SetFieldDiffUsdtReceived4Output(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtReceived4Output][i] += v
		return nothing
		end
	function SetFieldDiffAveragePurchasePrice(i::UInt32, v)::Nothing
		AddressStatisticsDict[:AveragePurchasePrice][i] += v
		return nothing
		end
	function SetFieldDiffLastSellPrice(i::UInt32, v)::Nothing
		AddressStatisticsDict[:LastSellPrice][i] += v
		return nothing
		end
	function SetFieldDiffUsdtNetRealized(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtNetRealized][i] += v
		return nothing
		end
	function SetFieldDiffUsdtNetUnrealized(i::UInt32, v)::Nothing
		AddressStatisticsDict[:UsdtNetUnrealized][i] += v
		return nothing
		end
	function SetFieldDiffBalance(i::UInt32, v)::Nothing
		AddressStatisticsDict[:Balance][i] += v
		return nothing
		end




















end
