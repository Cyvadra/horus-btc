
using JSON
using Dates
using Statistics

# Method: Smooth Timestamp
	function Smooth!(tsList::Vector{Int32})::Vector{Int32}
		lastTs      = copy(tsList[1])   # last continuous ts
		startPos    = 2                 # [1,1,2,2,2] ==> 1,3
		i           = max(3,findfirst(x->x!==lastTs,tsList))
		prevI       = startPos
		while !isnothing(i)
			if tsList[i] > lastTs     # trigger smooth
				if i > startPos+1
					cacheDiff = lastTs - tsList[startPos-1]
					numModi   = i - startPos
					valStep   = cacheDiff / numModi
					for j in startPos:(i-2)
						tsList[j] = round(Int32,
							tsList[startPos-1] + (j-startPos+1)*valStep
							)
					end
				end
				startPos  = i              # Mark start position
				lastTs    = tsList[i]
			elseif tsList[i] < lastTs    # unexpected data
				if tsList[startPos-1] < lastTs
					tsList[startPos-1] = tsList[i]
				end
				tsList[i] = lastTs
			end
			prevI  = i
			i      = findnext(x->x!==tsList[i], tsList, i)
		end
		cacheDiff = lastTs - tsList[startPos-1]
		numModi   = length(tsList) - startPos + 1
		valStep   = cacheDiff / numModi
		for j in startPos:length(tsList)
			tsList[j] = round(Int32,
				tsList[startPos-1] + (j-startPos+1)*valStep
				)
		end
		return tsList
		end

# Timezone + 8
	function dt2unix(dt::DateTime)::Int32
		return round(Int32, datetime2unix(dt - Hour(8)))
		end
	function unix2dt(ts)::DateTime
		return unix2datetime(ts) + Hour(8)
		end

	function showme()
		println(json(ans,2))
		return nothing
		end
	function showme(anything)
		println(json(anything,2))
		return nothing
		end

# Statistics
	safe_log(x)   = x > 0 ? log(1.0+x) : -log(1.0-x)
	safe_log2(x)  = x > 0 ? log2(1.0+x) : -log2(1.0-x)
	safe_log10(x) = x > 0 ? log10(1.0+x) : -log10(1.0-x)
	safe_sum(arr) = isempty(arr) ? 0 : sum(arr)
	safe_mean(arr) = isempty(arr) ? 0 : Statistics.mean(arr)
	function normalise(v::Vector, rng::UnitRange)::Vector
		v = deepcopy(v) .+ 0.00
		s = sort(v)
		vMin, vMax = s[1], s[end]
		vBias = vMax - vMin
		v .-= vMin
		v ./= vBias / (rng[end] - rng[1])
		v .+= rng[1]
		return v
		end

# Suggar
	function getTop(v::Vector, percent100::Real)
		return sort(v,rev=true)[ceil(Int,length(v)*percent100/100)]
		end
	function getBot(v::Vector, percent100::Real)
		return sort(v)[ceil(Int,length(v)*percent100/100)]
		end
	function getTop005(v::Vector)
		return sort(v,rev=true)[ceil(Int,length(v)*0.05)]
		end
	function getBot005(v::Vector)
		return sort(v)[ceil(Int,length(v)*0.05)]
		end
	function getPercent(v::Vector, percentage::Real)
		if length(v) == 0
			return 0.0
		end
		return v[ceil(Int,length(v)*percentage)]
		end













	# function normalize(v::Vector, n_remove=20)
	# 	s = sort(v)
	# 	vMin, vMax = s[n_remove], s[end-n_remove]
	# 	v = map(x->x < vMin ? vMin : x, v)
	# 	v = map(x->x > vMax ? vMax : x, v)
	# 	v = v .- vMin
	# 	m = max(v...) + min(v...) / 2
	# 	v = v .- 0.5m
	# 	v ./= 0.5m
	# 	return v
	# 	end












