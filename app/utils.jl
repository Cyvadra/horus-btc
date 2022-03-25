
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
		end

# Statistics
	function safe_log2(x)
		if x > 0
			return log2(x+1)
		else
			return -log2(abs(x)+1)
		end
		end
	function safe_log10(x)
		if x > 0
			return log10(x+1)
		else
			return -log10(abs(x)+1)
		end
		end
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












