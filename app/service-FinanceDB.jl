
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
TableTick.Open(true)
const baseTickTs = TableTick.GetFieldTimestamp(1) - 60

function ts2ind(ts)::Int32
	if ts - baseTickTs < 60
		return 1
	else
		return floor(Int32, (ts - baseTickTs)/60)
	end
	end
function ind2ts(i)
	return round(Int, baseTickTs+i*60)
	end

function GetBTCPriceWhen(ts)::Float32
	return TableTick.GetFieldClose(ts2ind(ts))
	end
function GetBTCPriceWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldClose(ts2ind.(ts))
	end
function GetBTCHighWhen(ts)::Float32
	return TableTick.GetFieldHigh(ts2ind(ts))
	end
function GetBTCHighWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldHigh(ts2ind.(ts))
	end
function GetBTCLowWhen(ts)::Float32
	return TableTick.GetFieldLow(ts2ind(ts))
	end
function GetBTCLowWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldLow(ts2ind.(ts))
	end


function syncBitcoin()
	# get derivative
	prevTs = TableTick.Findfirst(x->iszero(x), :Timestamp) |> x->x-1 |> TableTick.GetFieldTimestamp
	tmpN = (round(Int,time()) - round(Int,time()) % 60) - prevTs
	tmpN = ceil(Int, tmpN / 60)
	tmpN = min(tmpN, 1000)
	if tmpN < 2
		return prevTs
	end
	# fetch data
	url = "https://www.binance.com/api/v3/klines?startTime=$(prevTs)000&limit=$tmpN&symbol=BTCUSDT&interval=1m"
	run(pipeline(
		`proxychains4 curl $url`;
		stdout=cacheMarket,
		append=false
	));
	ret = JSON.Parser.parse(read(cacheMarket, String))[2:end]
	rm(cacheMarket)
	# write data
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
	if sysTimestamp > prevTs
		sleep(1)
		return syncBitcoin()
	end
	return prevTs
	end

