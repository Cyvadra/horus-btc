
include("./utils.jl");
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");

# Init
	AddressService.Open(false) # shall always

# Get latest timestamp
	function GetLastProcessedBlockN()::Int
		return Int(Timestamp2LastBlockN(GetLastProcessedTimestamp()))
		end
	lastProcessedBlockN = GetLastProcessedBlockN()

# Sync BlockPairs
# this loop will auto throw error when all synchronized
	function SyncBlockInfo()::Int
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
		return latestBlockHeight
		end
	SyncBlockInfo()
	ResyncBlockTimestamps()

# Timeline alignment
	function AlignToTimestamp(lastTs)::Nothing
		lastProcessedBlockN = GetLastProcessedBlockN()
		ts = BlockNum2Timestamp(lastProcessedBlockN)
		while ts < lastTs
			if ts + 86400 < lastTs
				ts += 86400
			else
				ts = lastTs
			end
			@info "Fetching tx till $(unix2datetime(ts)+Hour(8))"
			@info now()
			toN = Timestamp2LastBlockN(ts)
			arrayDiff = Address2StateDiff(lastProcessedBlockN, toN)
			@info "Merging state"
			@info now()
			MergeAddressState!(arrayDiff, GetBTCPriceWhen(ts))
			@info "merged"
			@assert GetLastProcessedBlockN() == Timestamp2LastBlockN(ts)
		end
		return nothing
		end

	include("./procedure-calculations.jl")

# Period predict
	intervalSecs = 10800
	function CalculateResults(fromTs, toTs)::Vector{ResultCalculations} # (fromTs, toTs]
		@assert fromTs % intervalSecs == 0
		@assert toTs % intervalSecs == 0
		toTs -= 1
		ret = Vector{ResultCalculations}()
		for ts in fromTs:intervalSecs:toTs
			fromBlockN = Timestamp2LastBlockN(ts)
			toBlockN   = Timestamp2LastBlockN(ts+intervalSecs)
			cacheAddrId = Vector{UInt32}()
			cacheTagNew = Vector{Bool}()
			cacheAmount = Vector{Float64}()
			cacheTs     = Vector{Int32}()
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
					map(x->datetime2unix.(x["timeNormalized"]), coins)
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
	lastTs    = GetLastProcessedTimestamp()
	currentTs = round( Int, now()-Hour(8) |> datetime2unix )
	fromTs = lastTs + intervalSecs - lastTs % intervalSecs
	toTs   = currentTs - currentTs % intervalSecs - 1
	AlignToTimestamp(fromTs)
	results   = ResultCalculations[]
	for ts in fromTs:intervalSecs:toTs
		append!(results, CalculateResults(ts, ts+intervalSecs))
		AlignToTimestamp(ts+intervalSecs)
	end


# Todo: partitions, test



