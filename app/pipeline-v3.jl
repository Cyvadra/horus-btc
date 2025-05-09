include("./utils.jl");
include("./config.jl");
include("./service-address.jl");
include("./service-address2id.jl");
include("./service-FinanceDB.jl");
# include("./service-btc.jl");
include("./service-mongo.jl");
include("./service-block_timestamp.jl");
include("./service-transactions.jl");
include("./middleware-calc_addr_diff.jl");
include("./procedure-calculations.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");

using ThreadSafeDicts # private repo
GlobalRuntime = ThreadSafeDict{String,Any}();
PipelineLocks = ThreadSafeDict{String, Bool}();
PipelineLocks["synchronizing"] = false
GlobalRuntime["runtime_assert"] = true

# Sync BlockPairs
	function GetLatestBlockNum()
		return Mongoc.find_one(MongoCollection("blocks"), options=Mongoc.BSON("""{"sort":{"height":-1}}"""))["height"]
		end
	function SyncBlockInfo()::Int
		lastBlockHeight = GetLastBlockNum()
		latestBlockHeight = GetLatestBlockNum()
		println("$(now()) \t Synchronizing Block Info: $lastBlockHeight ==> $latestBlockHeight")
		@showprogress for h in lastBlockHeight+1 : latestBlockHeight
			try
				ts = round(Int32, GetBlockInfo(h)["timeNormalized"] |> datetime2unix)
				TableBlockTimestamp.SetRow(h, h, ts)
			catch e
				@warn e
				break
			end
		end
		println()
		return latestBlockHeight
		end

# Digest transactions
	tmpBalanceDict = JLD2.load(rootPath*"/addr.balance.jld2")["tmpBalanceDict"]
	sizehint!(tmpBalanceDict, round(Int,1.88e9))
	tmpBalanceDiffDict = Dict{UInt32,Float64}()
	function DigestTransactionsOnBlock_direct(n)
		if GlobalRuntime["runtime_assert"]
			if iszero(n-1)
				TableTx.Config["lastNewID"] = 0
			end
			if n > 1
				tmpVal = TableTx.GetFieldBlockNum( GetSeqBlockCoinsRange(n-1)[end]+1 )
				if !iszero(tmpVal)
					@info "skip digest"
					return nothing
				end
			end
		end
		timeStamp = UInt32(round(Int, datetime2unix(
			GetBlockInfo(n)["timeNormalized"]
			)))
		inputs, outputs = GetBlockCoins(n)
		tmpList  = Vector{cacheTx}()
		global tmpBalanceDict, tmpBalanceDiffDict
		@assert length(tmpBalanceDiffDict) == 0
		# proceed block coins
			# inputs  = filter(x->x["spentHeight"]==n, tmpCoins)
			# outputs = filter(x->x["mintHeight"]==n, tmpCoins)
			addrs   = unique(vcat(
				map(x->x[1], inputs),
				map(x->x[1], outputs),
				))
			sizehint!(tmpBalanceDiffDict, length(addrs))
			for addr in addrs
				if !haskey(tmpBalanceDict, GenerateID(addr))
					tmpBalanceDict[HardReadID(addr)] = AddressService.GetFieldBalance(HardReadID(addr))
				end
				tmpBalanceDiffDict[HardReadID(addr)] = 0.0
			end
			tmpAmount = 0.0
			for c in inputs
				tmpAmount = -c[2]
				push!(tmpList, cacheTx(
					HardReadID(c[1]),
					n,
					tmpBalanceDict[HardReadID(c[1])],
					0.0,
					c[3],
					n,
					tmpAmount,
					timeStamp,
					))
				tmpBalanceDiffDict[HardReadID(c[1])] += tmpAmount
			end
			for c in outputs
				tmpAmount = c[2]
				push!(tmpList, cacheTx(
					HardReadID(c[1]),
					n,
					tmpBalanceDict[HardReadID(c[1])],
					0.0,
					n,
					0,
					tmpAmount,
					timeStamp,
					))
				tmpBalanceDiffDict[HardReadID(c[1])] += tmpAmount
			end
			for i in 1:length(tmpList)
				tmpVal = tmpList[i].balanceBeforeBlock + tmpBalanceDiffDict[tmpList[i].addressId]
				tmpList[i].balanceAfterBlock = tmpVal
				tmpBalanceDict[tmpList[i].addressId] = tmpVal
			end
			empty!(tmpBalanceDiffDict)
		# save to disk
			TableTx.BatchInsert(tmpList)
		return nothing
		end
	function DigestTransactionsOnBlock(n) # mongo
		if GlobalRuntime["runtime_assert"]
			if iszero(n-1)
				TableTx.Config["lastNewID"] = 0
			end
			if n > 1
				tmpVal = TableTx.GetFieldBlockNum( GetSeqBlockCoinsRange(n-1)[end]+1 )
				if !iszero(tmpVal)
					@info "skip digest"
					return nothing
				end
			end
		end
		timeStamp = UInt32(round(Int, datetime2unix(
			GetBlockInfo(n)["timeNormalized"]
			)))
		tmpCoins = GetBlockCoins(n)
		tmpList  = Vector{cacheTx}()
		global tmpBalanceDict, tmpBalanceDiffDict
		@assert length(tmpBalanceDiffDict) == 0
		# proceed block coins
			inputs  = filter(x->x["spentHeight"]==n, tmpCoins)
			outputs = filter(x->x["mintHeight"]==n, tmpCoins)
			addrs   = unique(vcat(
				map(x->x["address"], inputs),
				map(x->x["address"], outputs),
				))
			sizehint!(tmpBalanceDiffDict, length(addrs))
			for addr in addrs
				if !haskey(tmpBalanceDict, GenerateID(addr))
					tmpBalanceDict[HardReadID(addr)] = AddressService.GetFieldBalance(HardReadID(addr))
				end
				tmpBalanceDiffDict[HardReadID(addr)] = 0.0
			end
			tmpAmount = 0.0
			for c in inputs
				tmpAmount = -bitcoreInt2Float64(c["value"])
				push!(tmpList, cacheTx(
					HardReadID(c["address"]),
					n,
					tmpBalanceDict[HardReadID(c["address"])],
					0.0,
					c["mintHeight"],
					c["spentHeight"],
					tmpAmount,
					timeStamp,
					))
				tmpBalanceDiffDict[HardReadID(c["address"])] += tmpAmount
			end
			for c in outputs
				tmpAmount = bitcoreInt2Float64(c["value"])
				push!(tmpList, cacheTx(
					HardReadID(c["address"]),
					n,
					tmpBalanceDict[HardReadID(c["address"])],
					0.0,
					c["mintHeight"],
					c["spentHeight"],
					tmpAmount,
					timeStamp,
					))
				tmpBalanceDiffDict[HardReadID(c["address"])] += tmpAmount
			end
			for i in 1:length(tmpList)
				tmpVal = tmpList[i].balanceBeforeBlock + tmpBalanceDiffDict[tmpList[i].addressId]
				tmpList[i].balanceAfterBlock = tmpVal
				tmpBalanceDict[tmpList[i].addressId] = tmpVal
			end
			empty!(tmpBalanceDiffDict)
		# save to disk
			TableTx.BatchInsert(tmpList)
		return nothing
		end


# Period predict
	function CalculateResultOnBlock(n)::ResultCalculations
		coins = TableTx.GetRow(GetSeqBlockCoinsRange(n))
		coinsMint   = filter(x->x.mintHeight==n, coins)
		coinsSpent  = filter(x->x.spentHeight==n, coins)
		cacheAddrId = map(x->x.addressId, coinsMint)
		cacheAmount = abs.(map(x->x.amount, coinsMint))
		append!(cacheAddrId,
			map(x->x.addressId, coinsSpent)
			)
		append!(cacheAmount,
			0.0 .- abs.(map(x->x.amount, coinsSpent))
			)
		cacheTagNew = isNew(cacheAddrId)
		cacheTs = fill(BlockNum2Timestamp(n), length(cacheAmount))
		res = DoCalculations(cacheAddrId, cacheTagNew, cacheAmount, cacheTs)
		return res
		end

# Online Calculations
	function SyncResults()::Nothing
		if PipelineLocks["synchronizing"]
			return nothing
		end
		PipelineLocks["synchronizing"] = true
		SyncBlockInfo()
		if syncBitcoin() == false
			@warn "market data failure"
			PipelineLocks["synchronizing"] = false
			return nothing
		end
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
		# make sure bitcore has collected full data
		sleep(3)
		if toBlock - fromBlock < 3
			@info "sleep 5 seconds for synchronization..."
			sleep(5)
		end
		@showprogress for n in fromBlock:toBlock
			DigestTransactionsOnBlock(n)
			TableResults.SetRow(
				n,
				CalculateResultOnBlock(n)
			)
			MergeBlock2AddressState(n)
			GlobalRuntime["LastDoneBlock"] = n
		end
		PipelineLocks["synchronizing"] = false
		@info "Synchronization done."
		return nothing
		end

# for initialization
	function InitHistory(toDate::DateTime=DateTime(2017,12,24,20,0))::Nothing
		baseTs    = dt2unix(toDate)
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
		@info "Synchronizing from $lastBlockN to $toBlock"
		@showprogress for n in lastBlockN:toBlock
			DigestTransactionsOnBlock(n)
			MergeBlock2AddressState(n)
			GlobalRuntime["LastDoneBlock"] = n
		end
		return nothing
		end

# for test
	function GetAddressInfo(addr::AbstractString)::Nothing
		r = AddressService.GetRow(ReadID(addr))
		println(JSON.json(r,2))
		end

	function firstSync()
		AddressService.Create!(round(Int,1.88e9))
		TableResults.Create!(1999999)
		@info "$(now()) Initializing history..."
		InitHistory()
		@info "$(now()) Saving history..."
		AddressService.SaveCopy("/mnt/data/AddressServiceDB-backup/")
		AddressService.Close()
		TableResults.Close()
		AddressService.Open(true)
		TableResults.Open(true)
		GlobalRuntime["LastDoneBlock"] = GetLastProcessedTimestamp() |> Timestamp2LastBlockN
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
	function saveWorkspace()
		PipelineLocks["accepted"] = true
		@assert Timestamp2LastBlockN(GetLastProcessedTimestamp()) == GetLastResultsID()
		tmpId = GetLastResultsID()
		tmpFolder = "/mnt/array/$tmpId/"
		ispath(tmpFolder) ? nothing : mkdir(tmpFolder)
		@info "$(now()) Writing AddressService..."
		AddressService.SaveJLD(tmpFolder*"AddressServiceDB-v3/")
		@info "$(now()) Writing results..."
		TableResults.SaveCopy(tmpFolder*"results-flexible/")
		@info "$(now()) Writing address2id jld file..."
		SaveAddressIDs(tmpFolder*"addr.hashdict.jld2")
		@info "$(now()) Copying address log file..."
		flush(fileAddressLog)
		cp(logAddressString, tmpFolder*"addr.runtime.log")
		@info "$(now()) Copying transactions data..."
		TableTx.SaveJLD(tmpFolder*"transactions-btc/")
		@info "$(now()) Writing address balance..."
		JLD2.save(tmpFolder*"addr.balance.jld2", "tmpBalanceDict", tmpBalanceDict)
		@info "$(now()) Copying market data..."
		TableTick.SaveCopy(tmpFolder*"BTC_USDT_1m/")
		TableBlockTimestamp.SaveCopy(tmpFolder*"block-timestamp/")
		@info "$(now()) Done."
		PipelineLocks["accepted"] = false
		nothing
		end

	AddressService.Open(true)
	TableResults.Open(true)
	# TableTickIndex
		MmapDB.Init(folderMarket * "index/")
		TableTickIndex = MmapDB.GenerateCode(TickIndex3600)
		TableTickIndex.Open(true)
	@assert Timestamp2LastBlockN(GetLastProcessedTimestamp()) == GetLastResultsID()
	GlobalRuntime["LastDoneBlock"] = Timestamp2LastBlockN(GetLastProcessedTimestamp())
	SyncResults()

# listener
using Sockets
TRIGGER_SERVER = Sockets.TCPServer(; delay=false)
inet = Sockets.InetAddr("127.0.0.1",8021)
Sockets.bind(TRIGGER_SERVER, inet.host, inet.port; reuseaddr=true)
Sockets.listen(TRIGGER_SERVER)
PipelineLocks["accepted"] = false
PipelineLocks["emergency_stop"] = false
triggerRet = Vector{UInt8}("""HTTP/1.1 200 OK\nDate: Wed, 27 Jan 2021 21:16:00 UTC
Content-Length: 80\nContent-Type: text/plain\n
3.141592653589793238462643383279502884197169399375105820974944592307816406286198""");
function tcpTrigger(conn::TCPSocket)::Nothing
  try
    @info readline(conn)
    write(conn, triggerRet)
    close(conn)
	  if !PipelineLocks["accepted"]
	  	PipelineLocks["accepted"] = true
	  	try
		  	SyncResults()
		  catch e
		  	@warn e
		  	return nothing
		  finally
		  	PipelineLocks["accepted"] = false
		  end
	  end
  catch err
    print("connection ended with error $err")
  end
  return nothing
  end
SERVICE_TIRGGER = @async while true
	if PipelineLocks["emergency_stop"]
		break
	end
  conn = accept(TRIGGER_SERVER)
  tcpTrigger(conn)
  end
