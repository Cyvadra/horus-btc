
Lv0IndexP2PKH = Dict{String, Dict}()
	Lv1IndexP2PKH = Dict{String, Dict{String,UInt32}}()
	Lv2IndexP2PKH = Dict{String, UInt32}()
Lv0IndexP2SH = Dict{String, Dict}()
	Lv1IndexP2SH = Dict{String, Dict{String,UInt32}}()
	Lv2IndexP2SH = Dict{String, UInt32}()
Lv0IndexBech32 = Dict{String, Dict}()
	Lv1IndexBech32 = Dict{String, Dict{String,UInt32}}()
	Lv2IndexBech32 = Dict{String, UInt32}()
Lv0IndexOther = Dict{String, UInt32}()

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
			Lv0IndexP2PKH[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv0IndexP2PKH[lv0_prefix], lv1_prefix)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv0IndexP2PKH[lv0_prefix][lv1_prefix], lv2_body)
			return Lv0IndexP2PKH[lv0_prefix][lv1_prefix][lv2_body]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix][lv2_body] = n
			return n
		end
	elseif addr[1] == '3'
		lv0_prefix = string(addr[2:4])
		lv1_prefix = string(addr[5:7])
		lv2_body   = string(addr[8:end])
		if !haskey(Lv1IndexP2SH, lv0_prefix)
			Lv1IndexP2SH[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv1IndexP2SH[lv0_prefix], lv1_prefix)
			Lv1IndexP2SH[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv1IndexP2SH[lv0_prefix][lv1_prefix], lv2_body)
			return Lv1IndexP2SH[lv0_prefix][lv1_prefix][lv2_body]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			Lv1IndexP2SH[lv0_prefix][lv1_prefix][lv2_body] = n
			return n
		end
	elseif addr[1] == 'b' # bc1q
		lv0_prefix = string(addr[5:7])
		lv1_prefix = string(addr[8:10])
		lv2_body   = string(addr[11:end])
		if !haskey(Lv1IndexBech32, lv0_prefix)
			Lv1IndexBech32[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv1IndexBech32[lv0_prefix], lv1_prefix)
			Lv1IndexBech32[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv1IndexBech32[lv0_prefix][lv1_prefix], lv2_body)
			return Lv1IndexBech32[lv0_prefix][lv1_prefix][lv2_body]
		else
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
			Lv1IndexBech32[lv0_prefix][lv1_prefix][lv2_body] = n
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
		lv0_prefix = string(addr[2:5])
		lv1_prefix = string(addr[6:9])
		lv2_body   = string(addr[10:end])
		if !haskey(Lv0IndexP2PKH, lv0_prefix)
			Lv0IndexP2PKH[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv0IndexP2PKH[lv0_prefix], lv1_prefix)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv0IndexP2PKH[lv0_prefix][lv1_prefix], lv2_body)
			return Lv0IndexP2PKH[lv0_prefix][lv1_prefix][lv2_body]
		end
	elseif addr[1] == '3'
		lv0_prefix = string(addr[2:5])
		lv1_prefix = string(addr[6:9])
		lv2_body   = string(addr[10:end])
		if !haskey(Lv1IndexP2SH, lv0_prefix)
			Lv1IndexP2SH[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv1IndexP2SH[lv0_prefix], lv1_prefix)
			Lv1IndexP2SH[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv1IndexP2SH[lv0_prefix][lv1_prefix], lv2_body)
			return Lv1IndexP2SH[lv0_prefix][lv1_prefix][lv2_body]
		end
	elseif addr[1] == 'b' # bc1q
		lv0_prefix = string(addr[5:8])
		lv1_prefix = string(addr[9:12])
		lv2_body   = string(addr[13:end])
		if !haskey(Lv1IndexBech32, lv0_prefix)
			Lv1IndexBech32[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv1IndexBech32[lv0_prefix], lv1_prefix)
			Lv1IndexBech32[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv1IndexBech32[lv0_prefix][lv1_prefix], lv2_body)
			return Lv1IndexBech32[lv0_prefix][lv1_prefix][lv2_body]
		end
	else
		if haskey(Lv0IndexOther, addr)
			return Lv0IndexOther[addr]
		end
	end
	return zero(UInt32)
	end

function SetID(addr::String, id)::UInt32
	if addr[1] == '1'
		lv0_prefix = string(addr[2:5])
		lv1_prefix = string(addr[6:9])
		lv2_body   = string(addr[10:end])
		if !haskey(Lv0IndexP2PKH, lv0_prefix)
			Lv0IndexP2PKH[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv0IndexP2PKH[lv0_prefix], lv1_prefix)
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv0IndexP2PKH[lv0_prefix][lv1_prefix], lv2_body)
			return Lv0IndexP2PKH[lv0_prefix][lv1_prefix][lv2_body]
		else
			Lv0IndexP2PKH[lv0_prefix][lv1_prefix][lv2_body] = id
			return Lv0IndexP2PKH[lv0_prefix][lv1_prefix][lv2_body]
		end
	elseif addr[1] == '3'
		lv0_prefix = string(addr[2:5])
		lv1_prefix = string(addr[6:9])
		lv2_body   = string(addr[10:end])
		if !haskey(Lv1IndexP2SH, lv0_prefix)
			Lv1IndexP2SH[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv1IndexP2SH[lv0_prefix], lv1_prefix)
			Lv1IndexP2SH[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv1IndexP2SH[lv0_prefix][lv1_prefix], lv2_body)
			return Lv1IndexP2SH[lv0_prefix][lv1_prefix][lv2_body]
		else
			Lv1IndexP2SH[lv0_prefix][lv1_prefix][lv2_body] = id
			return Lv1IndexP2SH[lv0_prefix][lv1_prefix][lv2_body]
		end
	elseif addr[1] == 'b' # bc1q
		lv0_prefix = string(addr[5:8])
		lv1_prefix = string(addr[9:12])
		lv2_body   = string(addr[13:end])
		if !haskey(Lv1IndexBech32, lv0_prefix)
			Lv1IndexBech32[lv0_prefix] = Dict{String, Dict{String,UInt32}}()
		end
		if !haskey(Lv1IndexBech32[lv0_prefix], lv1_prefix)
			Lv1IndexBech32[lv0_prefix][lv1_prefix] = Dict{String,UInt32}()
		end
		if haskey(Lv1IndexBech32[lv0_prefix][lv1_prefix], lv2_body)
			return Lv1IndexBech32[lv0_prefix][lv1_prefix][lv2_body]
		else
			Lv1IndexBech32[lv0_prefix][lv1_prefix][lv2_body] = id
			return Lv1IndexBech32[lv0_prefix][lv1_prefix][lv2_body]
		end
	else
		if haskey(Lv0IndexOther, addr)
			return Lv0IndexOther[addr]
		else
			Lv0IndexOther[addr] = id
			return Lv0IndexOther[addr]
		end
	end
	end

nothing







