
# generate windowed view
ResultCalculations
TableResults
Timestamp2FirstBlockN
Timestamp2LastBlockN

function GenerateWindowedView_deprecated(intervalSecs::T, fromTs::T, toTs::T)::Vector{ResultCalculations} where T <: Signed
	ret = ResultCalculations[]
	for ts in fromTs+intervalSecs:intervalSecs:toTs
		tmpRes = TableResults.GetRow(
			Timestamp2FirstBlockN(ts-intervalSecs):Timestamp2LastBlockN(ts)
		)
		tmpLen = 0.0 + max(1, length(tmpRes))
		if length(tmpRes) == 0
			@warn ts
			@warn Timestamp2FirstBlockN(ts-intervalSecs), Timestamp2LastBlockN(ts)
			tmpSum = deepcopy(ret[end])
			tmpSum.timestamp = ts
			push!(ret, tmpSum)
			continue
		end
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
		# CellAddressBuyer
		tmpSum.balanceBuyerMean /= tmpLen
		tmpSum.balanceBuyerStd /= tmpLen
		tmpSum.balanceBuyerPercent20 /= tmpLen
		tmpSum.balanceBuyerPercent40 /= tmpLen
		tmpSum.balanceBuyerMiddle /= tmpLen
		tmpSum.balanceBuyerPercent60 /= tmpLen
		tmpSum.balanceBuyerPercent80 /= tmpLen
		tmpSum.balanceBuyerPercent95 /= tmpLen
		# CellAddressMomentum
		tmpSum.numSupplierMomentumMean = map(x->x.numSupplierMomentumMean, tmpRes) |> Statistics.mean
		tmpSum.numBuyerMomentumMean = map(x->x.numBuyerMomentumMean, tmpRes) |> Statistics.mean
		tmpSum.numRegularBuyerMomentumMean = map(x->x.numRegularBuyerMomentumMean, tmpRes) |> Statistics.mean
		push!(ret, tmpSum)
	end
	return ret
	end
function GenerateWindowedViewUTC(intervalSecs::T, fromTs::T, toTs::T)::Vector{ResultCalculations} where T <: Signed
	ret = ResultCalculations[]
	fromTs = fromTs - (fromTs % 86400) - intervalSecs
	toTs = toTs - (toTs % 86400)
	for ts in (fromTs+intervalSecs):intervalSecs:toTs
		tmpRes = TableResults.GetRow(
			Timestamp2FirstBlockN(ts-intervalSecs):Timestamp2LastBlockN(ts)
		)
		tmpLen = 0.0 + max(1, length(tmpRes))
		if length(tmpRes) == 0
			@warn ts
			@warn Timestamp2FirstBlockN(ts-intervalSecs), Timestamp2LastBlockN(ts)
			tmpSum = deepcopy(ret[end])
			tmpSum.timestamp = ts
			push!(ret, tmpSum)
			continue
		end
		# tmpSum = reduce(+, tmpRes)
		tmpSum = merge(tmpRes)
		tmpSum.timestamp = ts
		push!(ret, tmpSum)
	end
	return ret
	end	
function GenerateWindowedView(intervalSecs::T, fromTs::T, toTs::T)::Vector{ResultCalculations} where T <: Signed
	ret = ResultCalculations[]
	for ts in fromTs+intervalSecs:intervalSecs:toTs
		tmpRes = TableResults.GetRow(
			Timestamp2FirstBlockN(ts-intervalSecs):Timestamp2LastBlockN(ts)
		)
		tmpLen = 0.0 + max(1, length(tmpRes))
		if length(tmpRes) == 0
			@warn ts
			@warn Timestamp2FirstBlockN(ts-intervalSecs), Timestamp2LastBlockN(ts)
			tmpSum = deepcopy(ret[end])
			tmpSum.timestamp = ts
			push!(ret, tmpSum)
			continue
		end
		# tmpSum = reduce(+, tmpRes)
		tmpSum = merge(tmpRes)
		tmpSum.timestamp = ts
		push!(ret, tmpSum)
	end
	return ret
	end

function GenerateWindowedViewH1(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
	return GenerateWindowedView(Int32(3600), dt2unix(fromDate), dt2unix(toDate))
	end

function GenerateWindowedViewH2(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
	return GenerateWindowedView(Int32(7200), dt2unix(fromDate), dt2unix(toDate))
	end

function GenerateWindowedViewH3(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
	return GenerateWindowedView(Int32(10800), dt2unix(fromDate), dt2unix(toDate))
	end

function GenerateWindowedViewH6(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
	return GenerateWindowedView(Int32(21600), dt2unix(fromDate), dt2unix(toDate))
	end

function GenerateWindowedViewH12(fromDate::DateTime, toDate::DateTime)::Vector{ResultCalculations}
	return GenerateWindowedView(Int32(43200), dt2unix(fromDate), dt2unix(toDate))
	end
