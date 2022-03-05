module FinanceDB

	cacheMarket = "/tmp/market.json"

	using MmapDB, JSON, Dates

	MmapDB.Init("/mnt/data/BTC_USDT_1m/")

	mutable struct Tick
		Timestamp::Int32
		Open::Float32
		High::Float32
		Low::Float32
		Close::Float32
		MA10::Float32
		EMA60::Float32
		Volume::Float32
	end

	TableTick = MmapDB.GenerateCode(Tick)
	TableTick.Open(2333333)
	baseTs = TableTick.GetFieldTimestamp(1) - 60

	function ts2ind(ts)::Int32
		floor(Int32, (ts - baseTs)/60)
	end



	function syncBitcoin()
		# get derivative
		nextPos = findfirst(x->iszero(x), TableTick.TickDict[:Timestamp])
		ts  = TableTick.GetFieldTimestamp(nextPos-1)
		# fetch data
		url = "https://www.binance.com/api/v3/klines?startTime=$(ts)000&limit=1000&symbol=BTCUSDT&interval=1m"
		run(pipeline(
			`proxychains4 curl $url`;
			stdout=cacheMarket,
			append=false
		));
		ret = JSON.Parser.parse(read(cacheMarket, String))[2:end]
		rm(cacheMarket)
		# write data
		prevTs = TableTick.GetFieldTimestamp(nextPos-1)
		for i in 1:length(ret)
			currentTs = floor(Int, ret[i][1]/1000)
			if !iszero(currentTs - prevTs - 60)
				throw("error timestamp $currentTs $prevTs")
			end
			pos = ts2ind(currentTs)
			TableTick.SetRow(pos,
				currentTs,
				parse(Float32, ret[i][2]),
				parse(Float32, ret[i][3]),
				parse(Float32, ret[i][4]),
				parse(Float32, ret[i][5]),
				parse(Float32, ret[i][5]),
				parse(Float32, ret[i][5]),
				parse(Float32, ret[i][6])
			)
			prevTs = currentTs
		end
		sysTimestamp = round(Int,
			datetime2unix(
				now() - Hour(8) - Minute(30)
			)
		)
		@info "synchronized to $prevTs"
		if sysTimestamp > prevTs
			sleep(1)
			return syncBitcoin()
		end
		return prevTs
	end


end