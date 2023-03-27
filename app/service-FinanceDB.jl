using MmapDB, JSON, Dates

MmapDB.Init(folderMarket)

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

function GetBTCLastTs()::Int32
	(TableTick.Findfirst(x->iszero(x), :Timestamp) - 1) |> TableTick.GetFieldTimestamp
	end

function GetBTCOpenWhen(ts::Real)::Float32
	return TableTick.GetFieldOpen(ts2ind(ts))
	end
function GetBTCOpenWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldOpen(ts2ind.(ts))
	end

function GetBTCCloseWhen(ts::Real)::Float32
	return TableTick.GetFieldClose(ts2ind(ts))
	end
function GetBTCCloseWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldClose(ts2ind.(ts))
	end

function GetBTCHighWhen(ts::Real)::Float32
	return TableTick.GetFieldHigh(ts2ind(ts))
	end
function GetBTCHighWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldHigh(ts2ind.(ts))
	end

function GetBTCLowWhen(ts::Real)::Float32
	return TableTick.GetFieldLow(ts2ind(ts))
	end
function GetBTCLowWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldLow(ts2ind.(ts))
	end

function GetBTCPriceWhen(ts::Real)::Float32
	return TableTick.GetFieldClose(ts2ind(ts))
	end
function GetBTCPriceWhen(ts::Union{Vector,UnitRange})::Vector{Float32}
	return TableTick.GetFieldClose(ts2ind.(ts))
	end


function syncBitcoin()::Bool
	# get derivative
	prevTs = TableTick.Findfirst(iszero, :Timestamp) |> x->x-1 |> TableTick.GetFieldTimestamp
	tmpN = (round(Int,time()) - round(Int,time()) % 60) - prevTs
	tmpN = ceil(Int, tmpN / 60)
	tmpN = min(tmpN, 1000)
	if tmpN <= 1
		return true
	end
	# fetch data
	url = "https://www.binance.com/api/v3/klines?startTime=$(prevTs)000&limit=$tmpN&symbol=BTCBUSD&interval=1m"
	try
		sleep(1)
		run(pipeline(
			`proxychains4 curl $url`;
			stdout=cacheMarket,
			append=false
		));
	catch e
		@warn e
		return false
	end
	ret = JSON.Parser.parse(read(cacheMarket, String))[2:end]
	rm(cacheMarket)
	# write data
	for i in 1:length(ret)
		currentTs = round(Int, ret[i][1]/1000)
		if !iszero(currentTs - prevTs - 60)
			if currentTs > prevTs
				print(currentTs - prevTs - 60); print(' ')
				continue
			end
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
	@show unix2dt(prevTs)
	if sysTimestamp > prevTs
		sleep(1)
		return syncBitcoin()
	else
		syncBitcoinIndex()
	end
	return true
	end


mutable struct TickIndex3600 # 1h view
	Timestamp::Int32
	Open::Float32
	High::Float32
	Low::Float32
	Close::Float32
	Middle::Float32
	Average::Float32
	Volume::Float32
	end
function initFinanceIndex()
	tmpFolder = folderMarket * "index/"
	MmapDB.Init(tmpFolder)
	TableTickIndex = MmapDB.GenerateCode(TickIndex3600)
	TableTickIndex.Open(true)
	end
const baseTickIndexTs = TableTick.GetFieldTimestamp(1) - TableTick.GetFieldTimestamp(1) % 3600 + 7200
function ts2ind_findex(ts)::Int32
	if ts - baseTickIndexTs <= 0
		return 1
	else
		return ceil(Int32, (ts - baseTickIndexTs + 1)/3600)
	end
	end
function GetBTCLastTsIndex()::Int32
	(TableTickIndex.Findfirst(x->iszero(x), :Timestamp) - 1) |> TableTickIndex.GetFieldTimestamp
	end
function calcFinanceIndex(ts)
	ts = ts - ts % 3600
	tmpRng = ts2ind.(collect(ts-3600:60:ts))
	TableTickIndex.SetRow( ts2ind_findex(ts),
		ts,
		TableTick.GetFieldOpen(tmpRng[1]),
		reduce(max, TableTick.GetFieldHigh(tmpRng)),
		reduce(min, TableTick.GetFieldLow(tmpRng)),
		TableTick.GetFieldClose(tmpRng[end]),
		TableTick.GetFieldClose(tmpRng) |> middle,
		sum(
			(TableTick.GetFieldHigh(tmpRng) .+ TableTick.GetFieldLow(tmpRng)) .* TableTick.GetFieldVolume(tmpRng)
		) / sum(TableTick.GetFieldVolume(tmpRng)) / 2,
		sum(TableTick.GetFieldVolume(tmpRng)),
		)
	end
function syncBitcoinIndex()
	prevTs = TableTickIndex.Findfirst(x->iszero(x), :Timestamp) - 1 |> TableTickIndex.GetFieldTimestamp
	lastTs = (TableTick.Findfirst(x->iszero(x), :Timestamp) - 1) |> TableTick.GetFieldTimestamp
	if lastTs - prevTs >= 3600
		for t in prevTs+3600:3600:lastTs
			calcFinanceIndex(t)
		end
	end
	return nothing
	end

function GetBTCHighestWhen(ts::Union{Vector,UnitRange})::Float32
	@assert iszero(ts[end] % 3600)
	return reduce( max, TableTickIndex.GetFieldHigh(ts2ind_findex(t1):ts2ind_findex(t2)) )
	end
function GetBTCLowestWhen(ts::Union{Vector,UnitRange})::Float32
	@assert iszero(ts[end] % 3600)
	return reduce( min, TableTickIndex.GetFieldLow(ts2ind_findex(ts[1]):ts2ind_findex(ts[end])) )
	end










# eof
