using DataStructures
using ThreadSafeDicts # private repo
using JLD2

# Base Config
	const DATA_DIR = "/mnt/data/AddressServiceTrie/"

# AddressCounter
  CURRENT_MAX_N = UInt32(0)
  # auto load
  if filesize(DATA_DIR*"CURRENT_MAX_N") > 0
  	CURRENT_MAX_N = parse(UInt32, readline(DATA_DIR*"CURRENT_MAX_N"))
	  end
	mutable struct AddressCounterTpl
		dlock::Threads.SpinLock
		x::UInt32
		end
	AddressCounter = AddressCounterTpl(Threads.SpinLock(), CURRENT_MAX_N)

# Auto Save
  function WriteCounter()
  	write(DATA_DIR*"CURRENT_MAX_N", string(AddressCounter.x))
	  end
	function WriteTrieFile()
		@info "Writing Addresss Trie into $DATA_DIR..."
		@info "DO NOT TERMINATE NOW"
		JLD2.save(DATA_DIR*"Trie.RootP2PKH.jld2", "RootP2PKH", RootP2PKH)
		JLD2.save(DATA_DIR*"Trie.RootP2SH.jld2", "RootP2SH", RootP2SH)
		JLD2.save(DATA_DIR*"Trie.RootBech32.jld2", "RootBech32", RootBech32)
		JLD2.save(DATA_DIR*"Trie.RootOther.jld2", "RootOther", RootOther.d)
		@info "Synchronization Complete!"
		end
	atexit(WriteCounter)
	atexit(WriteTrieFile)

# Defaults
	const NUM_NOT_EXIST = UInt32(0)

# Fundamental others
	struct AddressSet
		listString::Vector{String}
		listId::Vector{UInt32}
		end
	tplAddressSet = AddressSet(String[], UInt32[])

# Fundamental Trie Trees
	RootP2PKH  = Trie{AddressSet}()
	RootP2SH   = Trie{AddressSet}()
	RootBech32 = Trie{AddressSet}()
	RootOther  = ThreadSafeDict{String, UInt32}()
	const firstLetterP2PKH  = '1'
	const firstLetterP2SH   = '3'
	const firstLetterBech32 = 'b'

# auto load
	if filesize(DATA_DIR*"Trie.RootOther.jld2") > 0
		RootP2PKH   = JLD2.load(DATA_DIR*"Trie.RootP2PKH.jld2", "RootP2PKH")
		RootP2SH    = JLD2.load(DATA_DIR*"Trie.RootP2SH.jld2", "RootP2SH")
		RootBech32  = JLD2.load(DATA_DIR*"Trie.RootBech32.jld2", "RootBech32")
		RootOther.d = JLD2.load(DATA_DIR*"Trie.RootOther.jld2", "RootOther")
	end

# Methods
	function ReadID(addr::AbstractString)::UInt32
		firstChar = addr[1]
		if firstChar == firstLetterP2PKH
			s = get(RootP2PKH, addr[2:5], NUM_NOT_EXIST)
			x = findfirst(x->x==addr[6:end], s.listString)
			isnothing(x) ? NUM_NOT_EXIST : s.listId[x]
		elseif firstChar == firstLetterP2SH
			s = get(RootP2SH, addr[2:5], NUM_NOT_EXIST)
			x = findfirst(x->x==addr[6:end], s.listString)
			isnothing(x) ? NUM_NOT_EXIST : s.listId[x]
		elseif firstChar == firstLetterBech32
			s = get(RootBech32, addr[5:9], NUM_NOT_EXIST)
			x = findfirst(x->x==addr[10:end], s.listString)
			isnothing(x) ? NUM_NOT_EXIST : s.listId[x]
		else
			if haskey(RootOther, addr)
				return RootOther[addr]
			else
				return NUM_NOT_EXIST
			end
		end
		end
	function SetID(addr::AbstractString, id)::Nothing
		firstChar = addr[1]
		if firstChar == firstLetterP2PKH
			s = get(RootP2PKH, addr[2:5], nothing)
			if isnothing(s)
				RootP2PKH[addr[2:5]] = AddressSet(String[], UInt32[])
				s = RootP2PKH[addr[2:5]]
			end
			x = findfirst(x->x==addr[6:end], s.listString)
			if isnothing(x)
				push!(RootP2PKH[addr[2:5]].listString, addr[6:end])
				push!(RootP2PKH[addr[2:5]].listId, id)
			end
		elseif firstChar == firstLetterP2SH
			s = get(RootP2SH, addr[2:5], nothing)
			if isnothing(s)
				RootP2SH[addr[2:5]] = AddressSet(String[], UInt32[])
				s = RootP2SH[addr[2:5]]
			end
			x = findfirst(x->x==addr[6:end], s.listString)
			if isnothing(x)
				push!(RootP2SH[addr[2:5]].listString, addr[6:end])
				push!(RootP2SH[addr[2:5]].listId, id)
			end
		elseif firstChar == firstLetterBech32
			s = get(RootBech32, addr[5:9], nothing)
			if isnothing(s)
				RootBech32[addr[5:9]] = AddressSet(String[], UInt32[])
				s = RootBech32[addr[5:9]]
			end
			x = findfirst(x->x==addr[10:end], s.listString)
			if isnothing(x)
				push!(RootBech32[addr[5:9]].listString, addr[10:end])
				push!(RootBech32[addr[5:9]].listId, id)
			end
		else
			RootOther[addr] = id
		end
		return nothing
		end
	function GenerateID(addr::AbstractString)::UInt32
		firstChar = addr[1]
		tmpRet = UInt32(1)
		if firstChar == firstLetterP2PKH
			s = get(RootP2PKH, addr[2:5], nothing)
			if isnothing(s)
				RootP2PKH[ addr[2:5] ] = AddressSet(String[], UInt32[])
				s = RootP2PKH[ addr[2:5] ]
			end
			x = findfirst(x->x==addr[6:end], s.listString)
			if isnothing(x)
				lock(AddressCounter.dlock)
				tmpRet += AddressCounter.x
				AddressCounter.x = tmpRet
				unlock(AddressCounter.dlock)
				push!(RootP2PKH[addr[2:5]].listId, tmpRet)
				push!(RootP2PKH[addr[2:5]].listString, addr[6:end])
			else
				tmpRet = s.listId[x]
			end
		elseif firstChar == firstLetterP2SH
			s = get(RootP2SH, addr[2:5], nothing)
			if isnothing(s)
				RootP2SH[ addr[2:5] ] = AddressSet(String[], UInt32[])
				s = RootP2SH[ addr[2:5] ]
			end
			x = findfirst(x->x==addr[6:end], s.listString)
			if isnothing(x)
				lock(AddressCounter.dlock)
				tmpRet += AddressCounter.x
				AddressCounter.x = tmpRet
				unlock(AddressCounter.dlock)
				push!(RootP2SH[addr[2:5]].listId, tmpRet)
				push!(RootP2SH[addr[2:5]].listString, addr[6:end])
			else
				tmpRet = s.listId[x]
			end
		elseif firstChar == firstLetterBech32
			s = get(RootBech32, addr[5:9], nothing)
			if isnothing(s)
				RootBech32[ addr[5:9] ] = AddressSet(String[], UInt32[])
				s = RootBech32[ addr[5:9] ]
			end
			x = findfirst(x->x==addr[10:end], s.listString)
			if isnothing(x)
				lock(AddressCounter.dlock)
				tmpRet += AddressCounter.x
				AddressCounter.x = tmpRet
				unlock(AddressCounter.dlock)
				push!(RootBech32[addr[5:9]].listId, tmpRet)
				push!(RootBech32[addr[5:9]].listString, addr[10:end])
			else
				tmpRet = s.listId[x]
			end
		elseif haskey(RootOther, addr)
			tmpRet = RootOther[addr]
		else
			lock(AddressCounter.dlock)
			tmpRet += AddressCounter.x
			AddressCounter.x = tmpRet
			unlock(AddressCounter.dlock)
			RootOther[addr] = tmpRet
		end
		return tmpRet
		end

























