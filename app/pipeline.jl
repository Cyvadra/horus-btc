
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
		if PipelineLocks["synchronizing"]
			return nothing
		end
		PipelineLocks["synchronizing"] = true
		syncBitcoin()
		SyncBlockInfo()
		ResyncBlockTimestamps()
		lastTs    = GetLastProcessedTimestamp()
		currentTs = round( Int, now()-Hour(8) |> datetime2unix )
		fromTs = lastTs + intervalSecs - lastTs % intervalSecs
		toTs   = currentTs - currentTs % intervalSecs - 1
		if toTs - fromTs < intervalSecs
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
	using Plots
	using Plotly
	using Statistics
	plotly()
	htmlCachePath = "/tmp/julia-online-plot.html"
	route("/sync") do
		t = now()
		SyncResults()
		"done in " * string( (now() - t).value / 1000 ) * "secs"
		end
	route("/view") do
		tmpVal  = TableResults.Findlast(x->!iszero(x), :timestamp)
		tmpRet  = TableResults.GetRow.(tmpVal-39:tmpVal)
		tmpSyms = collect(fieldnames(ResultCalculations))
		listTs  = map(x->x.timestamp, tmpRet)
		res = Dict{Symbol, Vector}()
		for sym in tmpSyms[2:end]
			res[sym] = map(x->getfield(x, sym), tmpRet)
		end
		Plots.plot([]);
		for p in res
			Plots.plot!(
				listTs, p[2];
				label = string(p[1]),
				color = "skyblue",
				alpha = 0.5,
			)
		end
		prices = GetBTCPriceWhen(listTs)
		Plots.plot!(listTs,
			prices;
			label = "market",
			color = "red",
			alpha = 0.8,
		)
		Plots.savefig(htmlCachePath)
		return read(htmlCachePath, String)
		end



	up(8023)

