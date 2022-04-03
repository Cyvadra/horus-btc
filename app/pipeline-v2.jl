
include("./utils.jl");
include("./service-address.jl");
include("./service-address2id.traditional.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./middleware-calc_addr_diff.jl");
include("./middleware-results-flexible.jl");
include("./procedure-calculations.jl");

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

# Period predict
	function CalculateResultOnBlock(n)::ResultCalculations
		ts    = BlockNum2Timestamp(n)
		coins = vcat(
			GetCoinsByMintHeight(n),
			GetCoinsBySpentHeight(n)
			)
		Random.shuffle!(shuffleRng, coins)
		addrs = map(x->GenerateID(x["address"]), coins)
		cacheAddrId = addrs
		cacheTagNew = isNew(addrs)
		cacheAmount = map(x->
			x["mintHeight"] == n ?
			bitcoreInt2Float64(x["value"]) :
			- bitcoreInt2Float64(x["value"])
			, coins)
		tmpTs = BlockNum2Timestamp(n-1)
		tmpInterval = (ts - tmpTs) / length(coins)
		cacheTs = round.(Int32,
			[ tmpTs + tmpInterval*i for i in 1:length(coins) ]
		)
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
		fromBlock = Timestamp2FirstBlockN(lastTs+1)
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

# for initialization
	function InitHistory()::Nothing
		baseTs    = TableTick.GetRow(1).Timestamp
		toBlock   = Timestamp2FirstBlockN(baseTs)
		tmpPrice  = GetBTCPriceWhen(baseTs)
		[ BlockPriceDict[i] = i * tmpPrice / toBlock for i in 1:toBlock ]; # overwrite middleware-calc_addr_diff.jl
		# MergeAddressState!( Address2StateDiff(0,1), zero(Float32) )
		lastBlockN = GetLastProcessedTimestamp() |> Timestamp2LastBlockN
		tmpStep    = 1
		@showprogress for n in lastBlockN:tmpStep:toBlock-tmpStep
			tmpEnd = min(n+tmpStep, toBlock)
			MergeAddressState!(
				Address2StateDiff(n, tmpEnd),
				BlockPriceDict[n]
			)
		end
		return nothing
		end
	if false
		InitHistory()
		AddressService.SaveCopy("/mnt/data/AddressServiceDB-backup/")
		SyncResults()
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

# generate windowed view
	# may need more accuracy
	function GenerateWindowedView(intervalSecs::T, fromTs::T, toTs::T)::Vector{ResultCalculations} where T <: Signed
		ret = ResultCalculations[]
		for ts in fromTs+intervalSecs:intervalSecs:toTs
			tmpRes = TableResults.GetRow(
				Timestamp2FirstBlockN(ts-intervalSecs):Timestamp2LastBlockN(ts)
			)
			tmpLen = length(tmpRes)
			tmpSum = reduce(+, tmpRes)
			tmpSum.timestamp = ts
			# CellAddressComparative
			tmpSum.percentBiasReference /= tmpLen
			tmpSum.percentNumNew /= tmpLen
			tmpSum.percentNumSending /= tmpLen
			tmpSum.percentNumReceiving /= tmpLen
			# CellAddressSupplier
			tmpSum.balanceSupplierMean /= tmpLen
			tmpSum.balanceSupplierStd /= tmpLen
			tmpSum.balanceSupplierPercent20 /= tmpLen
			tmpSum.balanceSupplierPercent40 /= tmpLen
			tmpSum.balanceSupplierMiddle /= tmpLen
			tmpSum.balanceSupplierPercent60 /= tmpLen
			tmpSum.balanceSupplierPercent80 /= tmpLen
			tmpSum.balanceSupplierPercent95 /= tmpLen
			push!(ret, tmpSum)
		end
		return ret
	end
	function GenerateWindowedViewH1(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
		return GenerateWindowedView(3600, dt2unix(fromDate), dt2unix(toDate))
		end
	function GenerateWindowedViewH2(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
		return GenerateWindowedView(7200, dt2unix(fromDate), dt2unix(toDate))
		end
	function GenerateWindowedViewH3(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
		return GenerateWindowedView(10800, dt2unix(fromDate), dt2unix(toDate))
		end
	function GenerateWindowedViewH12(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
		return GenerateWindowedView(43200, dt2unix(fromDate), dt2unix(toDate))
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

