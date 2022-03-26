
include("./utils.jl");
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");
include("./service-Results-H3.jl");

using ThreadSafeDicts # private

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
	function AlignToTimestamp(lastTs, fromTs)::Nothing
		lastProcessedBlockN = Timestamp2LastBlockN(lastTs)
		ts = BlockNum2Timestamp(lastProcessedBlockN)
		while ts < fromTs
			if ts + 86400 < fromTs
				ts += 86400
			else
				ts = fromTs
			end
			toN = Timestamp2LastBlockN(ts)
			if toN <= lastProcessedBlockN
				@info "Nothing to do from $lastProcessedBlockN to $toN"
				return nothing
			else
				@info "$(now()) Fetching tx till $(unix2datetime(ts)+Hour(8))"
			end
			arrayDiff = Address2StateDiff(lastProcessedBlockN, toN)
			@info "$(now()) Merging state $lastProcessedBlockN -> $toN"
			MergeAddressState!(arrayDiff, GetBTCPriceWhen(ts))
			@info "$(now()) merged"
			tmpTs = max( AddressService.GetFieldTimestampLastActive.( map(x->x.AddressId, arrayDiff) )... )
			@assert Timestamp2LastBlockN(tmpTs) == Timestamp2LastBlockN(ts)
		end
		return nothing
		end

	include("./procedure-calculations.jl")

# Period predict
	intervalSecs = 10800
	cacheAddrId = Vector{UInt32}()
	cacheTagNew = Vector{Bool}()
	cacheAmount = Vector{Float64}()
	cacheTs     = Vector{Int32}()
	function CalculateResults(fromTs, toTs)::Vector{ResultCalculations} # (fromTs, toTs]
		@assert fromTs % intervalSecs == 0
		@assert toTs % intervalSecs == 0
		toTs -= 1
		ret = Vector{ResultCalculations}()
		for ts in fromTs:intervalSecs:toTs
			fromBlockN = Timestamp2LastBlockN(ts)
			toBlockN   = Timestamp2LastBlockN(ts+intervalSecs)
			empty!(cacheAddrId)
			empty!(cacheTagNew)
			empty!(cacheAmount)
			empty!(cacheTs)
			for n in fromBlockN:toBlockN
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
				append!(cacheTs,
					fill(BlockNum2Timestamp(n), length(coins))
					)
			end
			Smooth!(cacheTs)
			res = DoCalculations(cacheAddrId, cacheTagNew, cacheAmount, cacheTs)
			res.timestamp = ts+intervalSecs
			push!(ret, res)
		end
		return ret
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
		currentTs = round( Int, now()-Hour(8) |> datetime2unix )
		fromTs = lastTs + intervalSecs - lastTs % intervalSecs
		toTs   = currentTs - currentTs % intervalSecs - 1
		if toTs - fromTs < intervalSecs - 1
			PipelineLocks["synchronizing"] = false
			return nothing
		else
			@info "Synchronizing from $(unix2dt(fromTs)) to $(unix2dt(toTs))"
		end
		AlignToTimestamp(lastTs, fromTs)
		for ts in fromTs:intervalSecs:toTs
			TableResults.SetRow(
				ts |> ts2resultsInd,
				CalculateResults(ts, ts+intervalSecs)[1]
			)
			AlignToTimestamp(ts, ts+intervalSecs)
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
	]
	switchView = true
	route("/sync") do
		t = now()
		SyncResults()
		"done in " * string( (now() - t).value / 1000 ) * "secs"
		end
	route("/view") do
		if !switchView
			return ""
		end
		tmpVal  = TableResults.Findlast(x->!iszero(x), :timestamp)
		tmpRet  = TableResults.GetRow.(tmpVal-nPlotPrev:tmpVal)
		tmpSyms = collect(fieldnames(ResultCalculations))
		listTs  = map(x->x.timestamp, tmpRet)
		basePrice = GetBTCPriceWhen(listTs[end])
		latestH   = 10Float16(
			reduce( max,
				GetBTCHighWhen(listTs[end]:round(Int,time()))
				) / basePrice - 1.0
			)
		latestL   = 10Float16(
			reduce( min,
				filter(x->x>0,
					GetBTCLowWhen(listTs[end]:round(Int,time()))
			) ) / basePrice - 1.0
			)
		traces = GenericTrace[]
		for sym in tmpSyms[2:end]
			if string(sym) in hiddenList
				continue
			end
			tmpList  = map(x->getfield(x, sym), tmpRet)
			# tmpList  = normalise(tmpList, displatRange)
			push!(traces, 
				PlotlyJS.scatter(x = listTs, y = tmpList,
					name = string(sym),
					marker_color = "skyblue",
				)
			)
		end
		prices = GetBTCPriceWhen(listTs)
		prices = normalise(prices, 100000:555000)
		push!(traces, 
			PlotlyJS.scatter(x = listTs, y = prices,
				name = "actual", marker_color = "black", yaxis = "actual")
		)
		f = open(htmlCachePath, "w")
		PlotlyJS.savefig(f,
			PlotlyJS.plot(
				traces,
				Layout(
					title_text = string(unix2dt(listTs[end])) * " $(latestL)‰ $(latestH)‰",
					xaxis_title_text = "timestamp",
				)
			);
			format = "html"
		)
		close(f)
		return read(htmlCachePath, String)
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
				) / basePrice - 1.0
			)
		latestL = Float16(
			reduce( min,
				filter(x->x>0,
					GetBTCLowWhen(listTs[end]:round(Int,time()))
			) ) / basePrice - 1.0
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

