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

# Fundamental Trie Trees
	RootP2PKH  = Trie{UInt32}()
	RootP2SH   = Trie{UInt32}()
	RootBech32 = Trie{UInt32}()
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
			return get(RootP2PKH, addr[2:end], NUM_NOT_EXIST)
		elseif firstChar == firstLetterP2SH
			return get(RootP2SH, addr[2:end], NUM_NOT_EXIST)
		elseif firstChar == firstLetterBech32
			return get(RootBech32, addr[5:end], NUM_NOT_EXIST)
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
			RootP2PKH[addr[2:end]] = id
		elseif firstChar == firstLetterP2SH
			RootP2SH[addr[2:end]] = id
		elseif firstChar == firstLetterBech32
			RootBech32[addr[5:end]] = id
		else
			RootOther[addr] = id
		end
		return nothing
		end
	function GenerateID(addr::AbstractString)::UInt32
		firstChar = addr[1]
		tmpRet = UInt32(0)
		if firstChar == firstLetterP2PKH
			tmpRet = get(RootP2PKH, addr[2:end], NUM_NOT_EXIST)
			if iszero(tmpRet)
				lock(AddressCounter.dlock)
				AddressCounter.x += 1
				tmpRet += AddressCounter.x
				RootP2PKH[addr[2:end]] = tmpRet
				unlock(AddressCounter.dlock)
			end
		elseif firstChar == firstLetterP2SH
			tmpRet = get(RootP2SH, addr[2:end], NUM_NOT_EXIST)
			if iszero(tmpRet)
				lock(AddressCounter.dlock)
				AddressCounter.x += 1
				tmpRet += AddressCounter.x
				RootP2SH[addr[2:end]] = tmpRet
				unlock(AddressCounter.dlock)
			end
		elseif firstChar == firstLetterBech32
			tmpRet = get(RootBech32, addr[5:end], NUM_NOT_EXIST)
			if iszero(tmpRet)
				lock(AddressCounter.dlock)
				AddressCounter.x += 1
				tmpRet += AddressCounter.x
				RootBech32[addr[5:end]] = tmpRet
				unlock(AddressCounter.dlock)
			end
		elseif haskey(RootOther, addr)
			tmpRet += RootOther[addr]
		else
			lock(AddressCounter.dlock)
			AddressCounter.x +=  1
			RootOther[addr] = AddressCounter.x
			tmpRet += AddressCounter.x
			unlock(AddressCounter.dlock)
		end
		return tmpRet
		end

























