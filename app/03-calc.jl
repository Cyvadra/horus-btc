using ProgressMeter
using Dates
using Statistics
# private repos
using MmapDB
using ThreadSafeDicts

include("./service-address.jl")
include("./service-FinanceDB.jl")
include("./02-loadmmap.jl")
include("./utils.jl")

@show Threads.nthreads()

# Config
	AddressService.Open()
	MmapDB.Init("/mnt/data/tmp/results")
	pairName = "BTC_USDT"
	seconds = (
		Hour  = 3600,
		Day   = 3600 * 24,
		Month = 3600 * 24 * 30,
		)
	intervals = (
			m15 = Minute(15),
			m20 = Minute(20),
			m30 = Minute(30),
			H1  = Hour(1), # main
			H2  = Hour(2),
			H3  = Hour(3),
			H4  = Hour(4),
			H6  = Hour(6),
			H8  = Hour(8),
			H12 = Hour(12),
			D1  = Day(1),
			D3  = Day(3),
			D5  = Day(5),
			W1  = Week(1),
			M1  = Month(1),
			M3  = Month(3),
			M6  = Month(6),
		)

	function SelectPeriod(fromDate::DateTime, toDate::DateTime, targetVector::Vector)::UnitRange{Int64}
		fromTs, toTs = dt2unix(fromDate), dt2unix(toDate)
		fromN = findfirst(x->x>=fromTs, targetVector)
		toN   = findlast(x->x<= toTs, targetVector)
		return fromN:toN
		end

#= DF structure
	TxRowsDF == DataFrame(
		:AddressId => rand(UInt32),
		:Amount => rand(Float64),
		:Timestamp => rand(Int32),
		)
	TxStateDF == DataFrame(
		:InputCount => rand(UInt16),
		:OutputCount => rand(UInt16),
		:Fee => rand(Float32),
		:Value => rand(Float32),
		:Timestamp => rand(Int32),
		)
	=#

# First version touch! function
	function touch!(fromI::Int, toI::Int)::Nothing
		coinPrice = 100.0
		coinUsdt  = 1000.0
		pos = 1
		for _ind in fromI:toI
			coinPrice = GetBTCPriceWhen(sumTs[_ind])
			coinUsdt  = abs(coinPrice * sumAmount[_ind])
			pos       = sumAddrId[_ind]
			if sumTagNew[_ind]
				if sumAmount[_ind] >= 0
					AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
					AddressService.SetFieldAmountIncomeTotal(pos, sumAmount[_ind])
					AddressService.SetFieldAmountExpenseTotal(pos, 0.0)
					AddressService.SetFieldNumTxInTotal(pos, 1)
					AddressService.SetFieldNumTxOutTotal(pos, 0)
					AddressService.SetFieldUsdtPayed4Input(pos, coinUsdt)
					AddressService.SetFieldUsdtReceived4Output(pos, 0.0)
					AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
					AddressService.SetFieldLastSellPrice(pos, coinPrice)
					AddressService.SetFieldUsdtNetRealized(pos, 0.0)
					AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
					AddressService.SetFieldBalance(pos, sumAmount[_ind])
				else
					AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
					AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
					AddressService.SetFieldAmountIncomeTotal(pos, 0.0)
					AddressService.SetFieldAmountExpenseTotal(pos, abs(sumAmount[_ind]))
					AddressService.SetFieldNumTxInTotal(pos, 0)
					AddressService.SetFieldNumTxOutTotal(pos, 1)
					AddressService.SetFieldUsdtPayed4Input(pos, 0.0)
					AddressService.SetFieldUsdtReceived4Output(pos, coinUsdt)
					AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
					AddressService.SetFieldLastSellPrice(pos, coinPrice)
					AddressService.SetFieldUsdtNetRealized(pos, coinUsdt)
					AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
					AddressService.SetFieldBalance(pos, sumAmount[_ind])
				end
				continue
			end
			tmpBalance = AddressService.GetFieldBalance(pos)
			if sumAmount[_ind] < 0
				AddressService.SetFieldDiffAmountExpenseTotal(pos, -sumAmount[_ind])
				AddressService.SetFieldDiffNumTxOutTotal(pos, 1)
				if AddressService.GetFieldTimestampLastPayed(pos) < sumTs[_ind]
					AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				end
				AddressService.SetFieldDiffUsdtReceived4Output(pos, coinUsdt)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
			else
				AddressService.SetFieldDiffAmountIncomeTotal(pos, sumAmount[_ind])
				AddressService.SetFieldDiffNumTxInTotal(pos, 1)
				if AddressService.GetFieldTimestampLastReceived(pos) < sumTs[_ind]
					AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				end
				AddressService.SetFieldDiffUsdtPayed4Input(pos, coinUsdt)
				if tmpBalance > 1e-9
					AddressService.SetFieldAveragePurchasePrice(pos,
						(coinUsdt + AddressService.GetFieldAveragePurchasePrice(pos) * tmpBalance) / (tmpBalance + sumAmount[_ind]) )
				else
					AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				end
			end
			if tmpBalance < 0 && AddressService.GetFieldTimestampCreated(pos) > sumTs[_ind]
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
			end
			if AddressService.GetFieldTimestampLastActive(pos) < sumTs[_ind]
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
			end
			AddressService.SetFieldDiffBalance(pos, sumAmount[_ind])
			AddressService.SetFieldUsdtNetRealized(pos,
				 AddressService.GetFieldUsdtReceived4Output(pos) - AddressService.GetFieldUsdtPayed4Input(pos)
				 )
			AddressService.SetFieldUsdtNetUnrealized(pos,
				 ( coinPrice - AddressService.GetFieldAveragePurchasePrice(pos) )
				 * AddressService.GetFieldBalance(pos)
				 )
		end
		return nothing
		end
	function touch!(_ind::Int)::Nothing
		coinPrice = 100.0
		coinUsdt  = 1000.0
		pos = 1
		coinPrice = GetBTCPriceWhen(sumTs[_ind])
		coinUsdt  = abs(coinPrice * sumAmount[_ind])
		pos       = sumAddrId[_ind]
		if sumTagNew[_ind]
			if sumAmount[_ind] >= 0
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, sumAmount[_ind])
				AddressService.SetFieldAmountExpenseTotal(pos, 0.0)
				AddressService.SetFieldNumTxInTotal(pos, 1)
				AddressService.SetFieldNumTxOutTotal(pos, 0)
				AddressService.SetFieldUsdtPayed4Input(pos, coinUsdt)
				AddressService.SetFieldUsdtReceived4Output(pos, 0.0)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, 0.0)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			else
				AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
				AddressService.SetFieldAmountIncomeTotal(pos, 0.0)
				AddressService.SetFieldAmountExpenseTotal(pos, abs(sumAmount[_ind]))
				AddressService.SetFieldNumTxInTotal(pos, 0)
				AddressService.SetFieldNumTxOutTotal(pos, 1)
				AddressService.SetFieldUsdtPayed4Input(pos, 0.0)
				AddressService.SetFieldUsdtReceived4Output(pos, coinUsdt)
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
				AddressService.SetFieldLastSellPrice(pos, coinPrice)
				AddressService.SetFieldUsdtNetRealized(pos, coinUsdt)
				AddressService.SetFieldUsdtNetUnrealized(pos, 0.0)
				AddressService.SetFieldBalance(pos, sumAmount[_ind])
			end
			return nothing
		end
		tmpBalance = AddressService.GetFieldBalance(pos)
		if sumAmount[_ind] < 0
			AddressService.SetFieldDiffAmountExpenseTotal(pos, -sumAmount[_ind])
			AddressService.SetFieldDiffNumTxOutTotal(pos, 1)
			if AddressService.GetFieldTimestampLastPayed(pos) < sumTs[_ind]
				AddressService.SetFieldTimestampLastPayed(pos, sumTs[_ind])
			end
			AddressService.SetFieldDiffUsdtReceived4Output(pos, coinUsdt)
			AddressService.SetFieldLastSellPrice(pos, coinPrice)
		else
			AddressService.SetFieldDiffAmountIncomeTotal(pos, sumAmount[_ind])
			AddressService.SetFieldDiffNumTxInTotal(pos, 1)
			if AddressService.GetFieldTimestampLastReceived(pos) < sumTs[_ind]
				AddressService.SetFieldTimestampLastReceived(pos, sumTs[_ind])
			end
			AddressService.SetFieldDiffUsdtPayed4Input(pos, coinUsdt)
			if tmpBalance > 1e-9
				AddressService.SetFieldAveragePurchasePrice(pos,
					(coinUsdt + AddressService.GetFieldAveragePurchasePrice(pos) * tmpBalance) / (tmpBalance + sumAmount[_ind]) )
			else
				AddressService.SetFieldAveragePurchasePrice(pos, coinPrice)
			end
		end
		if tmpBalance < 0 && AddressService.GetFieldTimestampCreated(pos) > sumTs[_ind]
			AddressService.SetFieldTimestampCreated(pos, sumTs[_ind])
		end
		if AddressService.GetFieldTimestampLastActive(pos) < sumTs[_ind]
			AddressService.SetFieldTimestampLastActive(pos, sumTs[_ind])
		end
		AddressService.SetFieldDiffBalance(pos, sumAmount[_ind])
		AddressService.SetFieldUsdtNetRealized(pos,
			 AddressService.GetFieldUsdtReceived4Output(pos) - AddressService.GetFieldUsdtPayed4Input(pos)
			 )
		AddressService.SetFieldUsdtNetUnrealized(pos,
			 ( coinPrice - AddressService.GetFieldAveragePurchasePrice(pos) )
			 * AddressService.GetFieldBalance(pos)
			 )
		return nothing
		end

	include("./procedure-calculations.jl")

# Generate AddressStatistics from TxRowsDF
	tplAddressStatistics = AddressStatistics(zeros(length(AddressStatistics.types))...)
	function GenerateAddrState(addrId::UInt32, ts::Int32)::AddressStatistics
		coinPrice = GetBTCPriceWhen(ts)
		ret    = deepcopy(tplAddressStatistics)
		tsLast = findlast(x->x<=ts, TxRowsDF.Timestamp)
		inds   = findall(x->x==addrId, TxRowsDF.AddressId[1:tsLast])
		ret.TimestampCreated = TxRowsDF.Timestamp[inds[1]]
		ret.TimestampLastActive = TxRowsDF.Timestamp[inds[end]]
		for i in length(inds):-1:1
			if TxRowsDF.Amount[i] < 0
				ret.TimestampLastPayed = TxRowsDF.Timestamp[i]
				break
			end
		end
		for i in length(inds):-1:1
			if TxRowsDF.Amount[i] > 0
				ret.TimestampLastReceived = TxRowsDF.Timestamp[i]
				break
			end
		end
		tmpIn   = filter(x->x>0, TxRowsDF.Amount[inds])
		tmpOut  = filter(x->x<0, TxRowsDF.Amount[inds])
		ret.AmountIncomeTotal  = sum(tmpIn)
		ret.AmountExpenseTotal = abs(sum(tmpOut))
		ret.NumTxInTotal  = length(tmpIn)
		ret.NumTxOutTotal = length(tmpOut)
		ret.LastSellPrice = GetBTCPriceWhen(ret.TimestampLastPayed)
		tmpUsdt   = [ GetBTCPriceWhen(TxRowsDF.Timestamp[_ind]) * TxRowsDF.Amount[_ind] for _ind in inds ]
		ret.UsdtPayed4Input      = sum(filter(x->x>0, tmpUsdt))
		ret.UsdtReceived4Output  = abs(sum(filter(x->x<0, tmpUsdt)))
		ret.Balance = ret.AmountIncomeTotal - ret.AmountExpenseTotal
		if ret.Balance > 0
			ret.AveragePurchasePrice = ret.UsdtPayed4Input / ret.Balance
		else
			ret.AveragePurchasePrice = coinPrice
		end
		ret.UsdtNetRealized = ret.UsdtReceived4Output - ret.UsdtPayed4Input
		ret.UsdtNetUnrealized = ret.Balance * (coinPrice - ret.AveragePurchasePrice)
		return ret
		end

# Processing
	fromDate = DateTime(2018,1, 1, 0, 0, 0)
	toDate   = DateTime(2021,12,24,23,59,59)
	posStart = SelectPeriod(fromDate, toDate, TxRowsDF.Timestamp)[1]
	# Sum data before, you can save this to a jld2 file
	# we suggest use the start time of market data, 2017
	# prog = ProgressMeter.Progress(posStart-2; barlen=64, color=:blue)

	# now it's time to process real stuff
	tmpLen = nrow(TxRowsDF)
	# pre alloc mem
	sumAddrId = deepcopy(TxRowsDF[posStart:tmpLen, :AddressId])
	sumTagNew = fill(true, tmpLen - posStart + 1)
	sumAmount = deepcopy(TxRowsDF[posStart:tmpLen, :Amount])
	sumTs     = deepcopy(TxRowsDF[posStart:tmpLen, :Timestamp])

	TxRowsDF = nothing
	@show now()
	@info "collecting varinfo"
	@show varinfo(r"TxRows")
	@show now()
	@info "gc complete"

	# go
	nextPosRef   = 1
	thisPosStart = 1
	thisPosEnd   = 1
	resLen       = ceil(Int, (toDate - fromDate).value / 1000 / 3600 / 3)
	TableResultCalculations = MmapDB.GenerateCode(ResultCalculations)
	TableResultCalculations.Open(resLen)
	resCounter = 1
	barLen   = findlast(x->x<=dt2unix(toDate), sumTs) - findfirst(x->x>=dt2unix(fromDate), sumTs) + 1
	prog     = ProgressMeter.Progress(barLen; barlen=36, color=:blue)
	for dt in fromDate:Hour(3):(toDate-Hour(3))
		if isfile("/tmp/JULIA_EMERGENCY_STOP")
			@show dt
			break
		end
		tsStart = dt2unix(dt)
		thisPosStart = findnext(x-> x >= tsStart, sumTs, nextPosRef)
		thisPosEnd   = findnext(x-> x > tsStart + 3seconds.Hour, sumTs, nextPosRef) - 1
		lenTxs = thisPosEnd - thisPosStart + 1
		lenNew = 0
		for i in 1:lenTxs
			_ind = thisPosStart+i-1
			sumTagNew[_ind] = AddressService.isNew(sumAddrId[_ind])
			if sumTagNew[_ind]
				lenNew += 1
			end
		end
		println()
		@info "New addresses: $lenNew / $lenTxs \t $(Float16(lenNew/lenTxs)*100)%"
		resultTpl = ResultCalculations(zeros(length(ResultCalculations.types))...)
		resultTpl.timestamp = tsStart
		lastI = 0
		# calc loop, in bach
		@info "length of transactions $lenTxs"
		t = @timed DoCalculations!(thisPosStart, thisPosEnd, Ref(resultTpl))
		@info "Calculation Time: $(Float16(t.time))s, gc $(Float16(t.gctime)), $(Float32(t.bytes / 1024^3))GB"
		t = now()
		a = round(Int, thisPosStart + lenTxs / 3)
		b = round(Int, thisPosStart + 2lenTxs / 3)
		touch!(thisPosStart, a)
		touch!(a+1, b)
		touch!(b+1, thisPosEnd)
		@info "Touch Time: $(Float16((now() - t).value / 1000))s"
		println()
		# debug
		if isinf(resultTpl.amountRealizedProfitBillion) || isnan(resultTpl.amountRealizedProfitBillion)
			@warn "inf detected"
			@show fromDate
			@show toDate
			@show thisPosStart
			@show thisPosEnd
			break
		end
		TableResultCalculations.SetRow(resCounter, resultTpl)
		resCounter += 1
		nextPosRef = thisPosEnd + 1
		next!( prog; step=(thisPosEnd - thisPosStart + 1) )
	end







# Analyze results
	# you are free to process simple indicators first
	# judge tx direction
	# compare with previous savepoint's account info
	# classify them into groups
	# trigger corresponding recorders
	# we do have snapshot formats of data, try split them into chunks! it'll do good to both you and your deep neural network!
	# ...








































