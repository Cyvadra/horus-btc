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
		if toBlock <= fromBlock
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

# then bring up service
	using Genie
	using DataFrames
	using PlotlyJS
	using Statistics
	include("./auth.jl")
	nPlotPrev     = round(Int, 24 / 3 * 5)
	htmlCachePath = "/tmp/julia-online-plot.html"
	displatRange  = 0:1000
	plotMaskName  = "_"*join(collect('a':'z'))*"_"
	hiddenList = String[
		"amountRecentD3", "numTotalRows", "amountTotalTransfer",
		"numWakeupW1Sending", "numWakeupW1Byuing",
		"numWakeupM1Sending", "numWakeupM1Byuing",
		"amountRecentD3Sending", "amountRecentD3Buying",
		"numRecentD3Sending", "numRecentD3Buying",
		"numTotalActive",
	]
	switchView = true
	priceRange = 10000:100000
	route("/sync") do
		t = now()
		SyncResults()
		"done in " * string( (now() - t).value / 1000 ) * "secs"
		end
	numSequenceReturn = 50
	cacheTs = round(Int,time())
	cacheDict = nothing

	route("/sequence") do
		global cacheTs
		global cacheDict
		# get params
		s = Genie.params(:session, "")
		n = parse(Int, Genie.params(:num, "3"))
		tmpWindow = parse(Int, Genie.params(:interval, "7200"))
		if length(s) < 10
			@warn s
			return ""
			end
		if !CheckScript(s)
			return ""
			end
		# check cache
		if round(Int,time()) - cacheTs < 60
			return json(cacheDict)
		else
			cacheTs = round(Int,time())
		end
		# sync
		SyncBlockInfo()
		ResyncBlockTimestamps()
		# syncBitcoin()
		tmpTs   = GetLastResultsTimestamp()
		if 0 < time() % 1800 < 300 && time() - tmpTs < 600
			tmpTs = round(Int, time())
		end
		tmpTs   = (tmpTs - tmpTs % 1800)
		tmpDt   = unix2dt(tmpTs)
		tmpRet  = GenerateWindowedView(Int32(tmpWindow), dt2unix(tmpDt-Day(n)), dt2unix(tmpDt))
		# ===== convert tmpRet =====
		tmpSyms = tmpRet[1] |> typeof |> fieldnames |> collect
		anoRet  = Dict{String,Vector}()
		for s in tmpSyms
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet)
		end
		# ===== end convert =====
		listTs  = anoRet["timestamp"]
		basePrice = GetBTCPriceWhen(listTs[end])
		latestH   = reduce( max,
			GetBTCHighWhen(listTs[end]:round(Int,time()))
			)
		latestL   = reduce( min,
			filter(x->x>0,
				GetBTCLowWhen(listTs[end]:round(Int,time()))
			)
			)
		prices = GetBTCPriceWhen(listTs)
		cacheDict = Dict(
				"results"   => anoRet,
				"prices"    => prices,
				"latestL"   => latestL,
				"latestH"   => latestH,
			)
		return json(cacheDict)
		end

	route("/market") do
		tmpVal  = TableResults.Findlast(x->!iszero(x), :timestamp)
		tmpRet  = TableResults.GetRow.(tmpVal-nPlotPrev:tmpVal)
		listTs  = map(x->x.timestamp, tmpRet)
		f = open(htmlCachePath, "w")
		basePrice = GetBTCPriceWhen(listTs[end])
		latestH = Float16(
			reduce( max,
				GetBTCHighWhen(listTs[end]:round(Int,time()))
			)
			)
		latestL = Float16(
			reduce( min,
				filter(x->x>0,
					GetBTCLowWhen(listTs[end]:round(Int,time()))
				)
			)
			)
		PlotlyJS.savefig(f,
			PlotlyJS.plot(
				GenericTrace[
					PlotlyJS.scatter(
						x = listTs, y = GetBTCHighWhen(listTs),
						name = "market", marker_color = "blue",
					),
					PlotlyJS.scatter(
						x = listTs, y = GetBTCLowWhen(listTs),
						name = plotMaskName, marker_color = "blue",
					)
				],
				Layout(
					title_text = string(unix2dt(listTs[end])) * " $latestL $latestH",
					xaxis_title_text = "timestamp",
				)
			);
			format = "html"
		)
		close(f)
		return read(htmlCachePath, String)
		end

	include("./functions-extend.jl")

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
	GlobalRuntime["LastDoneBlock"] = 556407
	SyncResults()

	SyncBlockInfo()
	ResyncBlockTimestamps()
	up(8023)

	@show bytes2hex(authString)
