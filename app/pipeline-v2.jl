
include("./utils.jl");
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");
include("./middleware-results-flexible.jl");

using ThreadSafeDicts # private repo

PipelineLocks = ThreadSafeDict{String, Bool}()

# Init
	AddressService.Open(false) # shall always

# Get latest timestamp
	# function GetLastProcessedBlockN()::Int
	# 	return Int(Timestamp2LastBlockN(GetLastProcessedTimestamp()))
	# 	end
	# lastProcessedBlockN = GetLastProcessedBlockN()

# Sync BlockPairs
# this loop will auto throw error when all synchronized
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
	SyncBlockInfo()
	ResyncBlockTimestamps()

# Timeline alignment
	function RecordAddrDiffOnBlock(toN)::Nothing
		lastProcessedBlockN = GetLastProcessedTimestamp() |> Timestamp2LastBlockN
		if toN <= lastProcessedBlockN
			@info "Nothing to do on $toN"
			return nothing
		else
			@info "$(now()) Fetching tx on $toN..."
		end
		# calc price
		ts = BlockNum2Timestamp(toN)
		tmpPrice  = GetBTCPriceWhen(ts-6:ts+6) |> sort |> x->x[7]
		arrayDiff = Address2StateDiff(lastProcessedBlockN, toN)
		MergeAddressState!(arrayDiff, tmpPrice)
		@info "$(now()) $toN merged."
		tmpTs = max( AddressService.GetFieldTimestampLastActive.( map(x->x.AddressId, arrayDiff) )... )
		@assert Timestamp2LastBlockN(tmpTs) == Timestamp2LastBlockN(ts)
		return nothing
		end

	include("./procedure-calculations.jl")

# Period predict
	cacheAddrId = Vector{UInt32}()
	cacheTagNew = Vector{Bool}()
	cacheAmount = Vector{Float64}()
	cacheTs     = Vector{Int32}()
	function CalculateResultOnBlock(n)::ResultCalculations
		empty!(cacheAddrId)
		empty!(cacheTagNew)
		empty!(cacheAmount)
		empty!(cacheTs)
		ts    = BlockNum2Timestamp(n)
		coins = GetCoinsByMintHeight(n)
		append!(coins, GetCoinsBySpentHeight(n))
		Random.shuffle!(shuffleRng, coins)
		addrs = map(x->GenerateID(x["address"]), coins)
		append!(cacheAddrId, addrs)
		append!(cacheTagNew, isNew(addrs))
		append!(cacheAmount,
			map(x->
				x["mintHeight"] == n ?
				bitcoreInt2Float64(x["value"]) :
				- bitcoreInt2Float64(x["value"])
				, coins)
			)
		tmpTs = BlockNum2Timestamp(n-1)
		tmpInterval = (ts - tmpTs) / length(coins)
		append!(cacheTs, round.(Int32,
			[ tmpTs + tmpInterval*i for i in 1:length(coins) ]
			))
		res = DoCalculations(cacheAddrId, cacheTagNew, cacheAmount, cacheTs)
		res.timestamp = cacheTs[end]
		return res
		end

# Online Calculations
	PipelineLocks["synchronizing"] = false
	function SyncResults()::Nothing
		syncBitcoin()
		if PipelineLocks["synchronizing"]
			return nothing
		end
		PipelineLocks["synchronizing"] = true
		SyncBlockInfo()
		ResyncBlockTimestamps()
		lastTs    = GetLastProcessedTimestamp()
		currentTs = round(Int, time())
		fromBlock = Timestamp2FirstBlockN(lastTs+10)
		toBlock   = Timestamp2LastBlockN(currentTs)
		if toBlock <= fromBlock
			PipelineLocks["synchronizing"] = false
			return nothing
		else
			@info "Synchronizing from $fromBlock to $toBlock"
		end
		for n in fromBlock:toBlock
			TableResults.SetRow(
				n,
				CalculateResultOnBlock(n)
			)
			RecordAddrDiffOnBlock(n)
		end
		PipelineLocks["synchronizing"] = false
		return nothing
		end

# for test
	function GetAddressInfo(addr::AbstractString)::Nothing
		r = AddressService.GetRow(ReadID(addr))
		println(JSON.json(r,2))
		end

# first complete state
	@info "$(now()) Synchronizing..."
	SyncResults()
	@info "$(now()) Synchronized."

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
	route("/sequence") do
		s = Genie.params(:session, "")
		if length(s) < 10
			@warn s
			return ""
			end
		if !CheckScript(s)
			return ""
			end
		tmpVal  = TableResults.Findlast(x->!iszero(x), :timestamp)
		tmpRet  = TableResults.GetRow.(tmpVal-50:tmpVal)
		listTs  = map(x->x.timestamp, tmpRet)
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
		return json(Dict(
				"results"   => tmpRet,
				"prices"    => prices,
				"latestL"   => latestL,
				"latestH"   => latestH,
			))
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
					title_text = string(unix2dt(listTs[end])) * " $latestL% $latestH%",
					xaxis_title_text = "timestamp",
				)
			);
			format = "html"
		)
		close(f)
		return read(htmlCachePath, String)
		end



	up(8023)

