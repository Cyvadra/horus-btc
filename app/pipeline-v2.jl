include("./utils.jl");
include("./config.jl");
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");
include("./procedure-calculations.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");

using ThreadSafeDicts # private repo
GlobalRuntime = ThreadSafeDict{String,Any}();
PipelineLocks = ThreadSafeDict{String, Bool}();
PipelineLocks["synchronizing"] = false

# Sync BlockPairs
	function SyncBlockInfo()::Int
		println("Synchronizing Block Info")
		latestBlockHeight = 1
		while true
			try
				latestBlockHeight = BlockPairs[end][1]
				ts = round(Int32, GetBlockInfo(latestBlockHeight+1)["timeNormalized"] |> datetime2unix)
				push!(BlockPairs, Pair{Int32, Int32}(latestBlockHeight+1, ts))
				print("$(latestBlockHeight+1)\t")
			catch
				println()
				return latestBlockHeight
			end
		end
		println()
		return latestBlockHeight
		end

# Period predict
	function CalculateResultOnBlock(n)::ResultCalculations
		coins = GetBlockCoins(n)
		coinsMint   = filter(x->x["mintHeight"]==n, coins)
		coinsSpent  = filter(x->x["spentHeight"]==n, coins)
		cacheAddrId = map(x->GenerateID(x["address"]), coinsMint)
		cacheAmount = bitcoreInt2Float64.(map(x->x["value"], coinsMint))
		append!(cacheAddrId,
			map(x->GenerateID(x["address"]), coinsSpent)
			)
		append!(cacheAmount,
			0 .- bitcoreInt2Float64.(map(x->x["value"], coinsSpent))
			)
		cacheTagNew = isNew(cacheAddrId)
		cacheTs = fill(BlockNum2Timestamp(n), length(cacheAmount))
		res = DoCalculations(cacheAddrId, cacheTagNew, cacheAmount, cacheTs)
		return res
		end

# Online Calculations
	function SyncResults()::Nothing
		SyncBlockInfo()
		ResyncBlockTimestamps()
		syncBitcoin()
		if PipelineLocks["synchronizing"]
			return nothing
		end
		PipelineLocks["synchronizing"] = true
		# lastTs    = GetLastProcessedTimestamp()
		currentTs = round(Int, time())
		fromBlock = GlobalRuntime["LastDoneBlock"] + 1
		toBlock   = Timestamp2LastBlockN(currentTs)
		if toBlock < fromBlock
			PipelineLocks["synchronizing"] = false
			return nothing
		else
			@info "Synchronizing from $fromBlock to $toBlock"
		end
		@showprogress for n in fromBlock:toBlock
			TableResults.SetRow(
				n,
				CalculateResultOnBlock(n)
			)
			MergeBlock2AddressState(n)
			GlobalRuntime["LastDoneBlock"] = n
		end
		PipelineLocks["synchronizing"] = false
		return nothing
		end

# for initialization
	function InitHistory()::Nothing
		baseTs    = DateTime(2019,1,1,0,0) |> dt2unix
		toBlock   = Timestamp2FirstBlockN(baseTs)
		tmpBlock  = TableTick.GetRow(1).Timestamp |> Timestamp2FirstBlockN
		tmpPrice  = GetBTCPriceWhen(tmpBlock)
		[ BlockPriceDict[i] = i * tmpPrice / toBlock for i in 1:tmpBlock ]; # overwrite dict in middleware-calc_addr_diff.jl
		lastBlockN = 1
		if !isnothing(
			AddressService.Findlast(x->!iszero(x), :TimestampLastActive)
			)
			lastBlockN = GetLastProcessedTimestamp() |> Timestamp2LastBlockN |> x->x+1
		end
		for n in lastBlockN:toBlock
			MergeBlock2AddressState(n)
			if rand() < 0.1
				print("$n \t")
			end
		end
		return nothing
		end

# for test
	function GetAddressInfo(addr::AbstractString)::Nothing
		r = AddressService.GetRow(ReadID(addr))
		println(JSON.json(r,2))
		end

	function firstSync()
		AddressService.Create!(round(Int,1.2e9))
		TableResults.Create!(999999)
		@info "$(now()) Initializing history..."
		InitHistory()
		@info "$(now()) Saving history..."
		AddressService.SaveCopy("/mnt/data/AddressServiceDB-backup/")
		AddressService.Close()
		TableResults.Close()
		AddressService.Open(false)
		TableResults.Open(true)
		@info "$(now()) Synchronizing to present..."
		SyncResults()
		@info "$(now()) Pulling up service..."
		end
	function regularSync()
		AddressService.Open(false)
		TableResults.Open(true)
		@info "$(now()) Synchronizing to present..."
		SyncResults()
		@info "$(now()) Pulling up service..."
		end

	AddressService.Open(true)
	TableResults.Open(true)
	GlobalRuntime["LastDoneBlock"] = 736186
	# SyncResults()

	SyncBlockInfo()
	ResyncBlockTimestamps()
