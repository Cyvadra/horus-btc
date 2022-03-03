using DataStructures
using ThreadSafeDicts # private repo

# Base Config
	const DATA_DIR = "/mnt/data/AddressServiceTrie/"

# Config: CURRENT_MAX_N
  CURRENT_MAX_N = UInt32(0)
  if filesize(DATA_DIR*"CURRENT_MAX_N") > 0
  	CURRENT_MAX_N = parse(UInt32, readline(DATA_DIR*"CURRENT_MAX_N"))
	  end
	struct AddressCounterTpl
		dlock::Threads.SpinLock
		x::UInt32
		end
	AddressCounter = AddressCounterTpl(Threads.SpinLock(), CURRENT_MAX_N)
  function WriteCounter()
  	write(DATA_DIR*"CURRENT_MAX_N", string(AddressCounter.x))
	  end
	atexit(WriteCounter)

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
				AddressCounter.x = AddressCounter.x + 1
				tmpRet = AddressCounter.x
				RootP2PKH[addr[2:end]] = tmpRet
				unlock(AddressCounter.dlock)
			end
		elseif firstChar == firstLetterP2SH
			tmpRet = get(RootP2SH, addr[2:end], NUM_NOT_EXIST)
			if iszero(tmpRet)
				lock(AddressCounter.dlock)
				AddressCounter.x = AddressCounter.x + 1
				tmpRet = AddressCounter.x
				RootP2SH[addr[2:end]] = tmpRet
				unlock(AddressCounter.dlock)
			end
		elseif firstChar == firstLetterBech32
			tmpRet = get(RootBech32, addr[5:end], NUM_NOT_EXIST)
			if iszero(tmpRet)
				lock(AddressCounter.dlock)
				AddressCounter.x = AddressCounter.x + 1
				tmpRet = AddressCounter.x
				RootBech32[addr[5:end]] = tmpRet
				unlock(AddressCounter.dlock)
			end
		elseif haskey(RootOther, addr)
			tmpRet = RootOther[addr]
		else
			lock(AddressCounter.dlock)
			AddressCounter.x = AddressCounter.x + 1
			tmpRet = AddressCounter.x
			RootOther[addr] = tmpRet
			unlock(AddressCounter.dlock)
		end
		return tmpRet
		end

























