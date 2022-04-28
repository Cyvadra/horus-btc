using Statistics

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

function meanfit(v::Vector)::Vector
	return 2sortperm(v) ./ length(v) .- 1
	end














