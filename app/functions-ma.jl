using Statistics
using StatsBase

function sma(v::Vector{T}, numMa::Int)::Vector where T<:Real
	if length(v) < 3numMa
		throw("insufficient data")
	end
	vRet = zeros(length(v))
	vRet[1] = v[1]
	for i in 2:numMa+1
		vRet[i] = Statistics.mean(v[1:i-1])
	end
	for i in numMa+2:length(v)
		vRet[i] = (numMa * vRet[i-1] - v[i-numMa-1] + v[i-1]) / numMa
	end
	return vRet
	end

function ma(v::Vector{T}, numMa::Int)::Vector where T<:Real
	vRet = zeros(length(v))
	vRet[1] = v[1]
	for i in 2:length(v)
		vRet[i] = ((numMa-1)*vRet[i-1] + v[i-1]) / numMa
	end
	return vRet
	end

function ema(v::Vector{T}, numMa::Int)::Vector where T<:Real
	vRet = zeros(length(v))
	vRet[1] = v[1]
	for i in 2:length(v)
		vRet[i] = ((numMa-1)*vRet[i-1] + 2v[i-1]) / (numMa+1)
	end
	return vRet
	end

function permfit(v::Vector)::Vector
	return sortperm(v) ./ length(v)
	end

function logfit(v::Vector)::Vector
	v .*= 1e3
	v = log.(v)
	s = sort(v)
	vMid = s[round(Int,length(v)/2)]
	vMin, vMax = s[1], s[end]
	bMin, bMax = vMid-vMin, vMax-vMid
	vRet = zeros(length(v))
	for i in 1:length(v)
		tmpVal = v[i]-vMid
		if tmpVal < 0
			vRet[i] = tmpVal / bMin
		else
			vRet[i] = tmpVal / bMax
		end
	end
	return vRet
	end

function histofit(v::Vector)::Vector
	# init values
	leftEdge, rightEdge = min(v...), max(v...)
	tmpRes     = fit(Histogram, v; nbins=20)
	tmpEdges   = collect(tmpRes.edges)[1]
	# get central value
	centralPos = findmax(tmpRes.weights)[2]
	centralVal = (tmpEdges[centralPos] + tmpEdges[centralPos+1]) / 2
	# ignore polar points
	tmpWeights = tmpRes.weights
	for i in 1:length(tmpWeights)-1
		if sum(tmpWeights[i+1:end]) <= tmpWeights[i]
			rightEdge = tmpEdges[min(end,i+2)]
			break
		end
	end
	for i in length(tmpWeights):-1:3
		if sum(tmpWeights[1:i-1]) <= tmpWeights[i]
			leftEdge = tmpEdges[max(1,i-2)]
		end
	end
	bRight = rightEdge - centralVal
	bLeft  = centralVal - leftEdge
	if centralPos > 2
		return (v .- centralVal) ./ max(bLeft, bRight)
	else
		return v ./ max(bLeft, bRight)
	end
	end

function removePolars!(v::Vector)::Vector
	leftEdge   = min(v...)
	rightEdge  = max(v...)
	tmpRes     = fit(Histogram, v)
	tmpEdges   = collect(tmpRes.edges[1])
	# ignore polar points
	tmpWeights = tmpRes.weights
	for i in length(tmpWeights):-1:2
		if sum(tmpWeights[1:i-1]) <= tmpWeights[i]
			leftEdge = tmpEdges[max(1,i-1)]
			for j in 1:length(v)
				if v[j] < leftEdge
					v[j] = leftEdge
				end
			end
			break
		end
	end
	for i in 1:length(tmpWeights)-1
		if sum(tmpWeights[i+1:end]) <= tmpWeights[i]
			rightEdge = tmpEdges[i+2]
			for j in 1:length(v)
				if v[j] > rightEdge
					v[j] = rightEdge
				end
			end
			break
		end
	end
	return v
	end












