

mutable struct Lv2Unit
	strings::Vector{String}
	ids::Vector{UInt32}
	end
Lv0IndexP2PKH = Dict{String, Dict}()
	# Lv1IndexP2PKH = Dict{String, Lv2Unit}()
	# Lv2AddrStringVectorP2PKH = Vector{String}()
	# Lv2AddrIdVectorP2PKH = Vector{UInt32}()
Lv0IndexP2SH = Dict{String, Dict}()
	# Lv1IndexP2SH = Dict{String, Lv2Unit}()
	# Lv2AddrStringVectorP2SH = Vector{String}()
	# Lv2AddrIdVectorP2SH = Vector{UInt32}()
Lv0IndexBech32 = Dict{String, Dict}()
	# Lv1IndexBech32 = Dict{String, Lv2Unit}()
	# Lv2AddrStringVectorBech32 = Vector{String}()
	# Lv2AddrIdVectorBech32 = Vector{UInt32}()
Lv0IndexOther = Dict{String, UInt32}()

empty!(Lv0IndexP2PKH)
empty!(Lv0IndexP2SH)
empty!(Lv0IndexBech32)
empty!(Lv0IndexOther)

mutable struct MaxAddressNumberTpl
	id::UInt32
	dlock::Threads.SpinLock
	end
MaxAddressNumber = MaxAddressNumberTpl(1, Threads.SpinLock())

function String2ID(addr::String)::UInt32
	if addr[1] == '1'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv0IndexP2PKH, lv0_prefix)
			Lv0IndexP2PKH[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexP2PKH[lv0_prefix], lv1_prefix)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexP2PKH[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			return Lv0IndexP2PKH[lv0_prefix][lv1_prefix].ids[i]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			push!(Lv0IndexP2PKH[lv0_prefix][lv1_prefix].strings, lv2_body)
			push!(Lv0IndexP2PKH[lv0_prefix][lv1_prefix].ids, n)
			return n
		end
	elseif addr[1] == '3'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv0IndexP2SH, lv0_prefix)
			Lv0IndexP2SH[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexP2SH[lv0_prefix], lv1_prefix)
			Lv0IndexP2SH[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexP2SH[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			return Lv0IndexP2SH[lv0_prefix][lv1_prefix].ids[i]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			push!(Lv0IndexP2SH[lv0_prefix][lv1_prefix].strings, lv2_body)
			push!(Lv0IndexP2SH[lv0_prefix][lv1_prefix].ids, n)
			return n
		end
	elseif addr[1] == 'b' # bc1q
		lv0_prefix = string(addr[5:7])
		lv1_prefix = string(addr[8:10])
		lv2_body   = string(addr[11:end])
		if !haskey(Lv0IndexBech32, lv0_prefix)
			Lv0IndexBech32[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexBech32[lv0_prefix], lv1_prefix)
			Lv0IndexBech32[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexBech32[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			return Lv0IndexBech32[lv0_prefix][lv1_prefix].ids[i]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			push!(Lv0IndexBech32[lv0_prefix][lv1_prefix].strings, lv2_body)
			push!(Lv0IndexBech32[lv0_prefix][lv1_prefix].ids, n)
			return n
		end
	else
		if haskey(Lv0IndexOther, addr)
			return Lv0IndexOther[addr]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			Lv0IndexOther[addr] = n
			return n
		end
	end
	return n
	end

function String2IDSafe(addr::String)::UInt32
	if addr[1] == '1'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv0IndexP2PKH, lv0_prefix)
			Lv0IndexP2PKH[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexP2PKH[lv0_prefix], lv1_prefix)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexP2PKH[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			return Lv0IndexP2PKH[lv0_prefix][lv1_prefix].ids[i]
		else
			return zero(UInt32)
		end
	elseif addr[1] == '3'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv0IndexP2SH, lv0_prefix)
			Lv0IndexP2SH[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexP2SH[lv0_prefix], lv1_prefix)
			Lv0IndexP2SH[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexP2SH[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			return Lv0IndexP2SH[lv0_prefix][lv1_prefix].ids[i]
		else
			return zero(UInt32)
		end
	elseif addr[1] == 'b' # bc1q
		lv0_prefix = string(addr[5:7])
		lv1_prefix = string(addr[8:10])
		lv2_body   = string(addr[11:end])
		if !haskey(Lv0IndexBech32, lv0_prefix)
			Lv0IndexBech32[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexBech32[lv0_prefix], lv1_prefix)
			Lv0IndexBech32[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexBech32[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			return Lv0IndexBech32[lv0_prefix][lv1_prefix].ids[i]
		else
			return zero(UInt32)
		end
	else
		if haskey(Lv0IndexOther, addr)
			return Lv0IndexOther[addr]
		else
			return zero(UInt32)
		end
	end
	end

function SetID(addr::String, id)::Nothing
	if addr[1] == '1'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv0IndexP2PKH, lv0_prefix)
			Lv0IndexP2PKH[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexP2PKH[lv0_prefix], lv1_prefix)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexP2PKH[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix].ids[i] = id
			return nothing
		else
			lock(MaxAddressNumber.dlock)
			MaxAddressNumber.id = max(MaxAddressNumber.id, id)
			unlock(MaxAddressNumber.dlock)
			push!(Lv0IndexP2PKH[lv0_prefix][lv1_prefix].strings, lv2_body)
			push!(Lv0IndexP2PKH[lv0_prefix][lv1_prefix].ids, id)
			return nothing
		end
	elseif addr[1] == '3'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv0IndexP2SH, lv0_prefix)
			Lv0IndexP2SH[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexP2SH[lv0_prefix], lv1_prefix)
			Lv0IndexP2SH[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexP2SH[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			Lv0IndexP2SH[lv0_prefix][lv1_prefix].ids[i] = id
			return nothing
		else
			lock(MaxAddressNumber.dlock)
			MaxAddressNumber.id = max(MaxAddressNumber.id, id)
			unlock(MaxAddressNumber.dlock)
			push!(Lv0IndexP2SH[lv0_prefix][lv1_prefix].strings, lv2_body)
			push!(Lv0IndexP2SH[lv0_prefix][lv1_prefix].ids, id)
			return nothing
		end
	elseif addr[1] == 'b' # bc1q
		lv0_prefix = string(addr[5:7])
		lv1_prefix = string(addr[8:10])
		lv2_body   = string(addr[11:end])
		if !haskey(Lv0IndexBech32, lv0_prefix)
			Lv0IndexBech32[lv0_prefix] = Dict{String, Lv2Unit}()
		end
		if !haskey(Lv0IndexBech32[lv0_prefix], lv1_prefix)
			Lv0IndexBech32[lv0_prefix][lv1_prefix] = Lv2Unit(String[], UInt32[])
		end
		i = findfirst(x->x==lv2_body, Lv0IndexBech32[lv0_prefix][lv1_prefix].strings)
		if !isnothing(i)
			Lv0IndexBech32[lv0_prefix][lv1_prefix].ids[i] = id
			return nothing
		else
			lock(MaxAddressNumber.dlock)
			MaxAddressNumber.id = max(MaxAddressNumber.id, id)
			unlock(MaxAddressNumber.dlock)
			push!(Lv0IndexBech32[lv0_prefix][lv1_prefix].strings, lv2_body)
			push!(Lv0IndexBech32[lv0_prefix][lv1_prefix].ids, id)
			return nothing
		end
	else
		if haskey(Lv0IndexOther, addr)
			Lv0IndexOther[addr] = id
			return nothing
		else
			lock(MaxAddressNumber.dlock)
			MaxAddressNumber.id = max(MaxAddressNumber.id, id)
			unlock(MaxAddressNumber.dlock)
			Lv0IndexOther[addr] = id
			return nothing
		end
	end
	return nothing
	end



nothing







