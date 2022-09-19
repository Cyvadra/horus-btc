include("./utils.jl");
include("./config.jl");
include("./service-address.jl");
include("./service-address2id.jl");
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
				latestBlockHeight = GetLastBlockNum()
				ts = round(Int32, GetBlockInfo(latestBlockHeight+1)["timeNormalized"] |> datetime2unix)
				TableBlockTimestamp.SetRow(latestBlockHeight+1, latestBlockHeight+1, ts)
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
		AddressService.Create!(round(Int,1.28e9))
		TableResults.Create!(999999)
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
		@assert Timestamp2LastBlockN(GetLastProcessedTimestamp()) == GetLastResultsID()
		tmpId = GetLastResultsID()
		tmpFolder = "/media/jason89757/hdd/$tmpId/"
		ispath(tmpFolder) ? nothing : mkdir(tmpFolder)
		AddressService.SaveCopy(tmpFolder*"AddressServiceDB-v2/")
		TableResults.SaveCopy(tmpFolder*"results-flexible/")
		@info "Writing address2id jld file..."
		SaveAddressIDs(tmpFolder*"addr.hashdict.jld2")
		@info "Copying address log file..."
		flush(fileAddressLog)
		cp(logAddressString, tmpFolder*"addr.runtime.log")
		@info "Done."
		end

	AddressService.Open(true)
	TableResults.Open(true)
	GlobalRuntime["LastDoneBlock"] = GetLastResultsID()
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
		  end
	  	PipelineLocks["accepted"] = false
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
