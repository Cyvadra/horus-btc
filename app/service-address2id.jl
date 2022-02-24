
	
	strFolder = "/media/jason89757/gloway/AddressServiceString/"
	isdir(strFolder) || mkdir(strFolder)
	previousMaxN = parse(UInt32, readline(strFolder*"counter"))

	mutable struct MaxAddressNumberTpl
		id::UInt32
		dlock::Threads.SpinLock
	end
	MaxAddressNumber = MaxAddressNumberTpl(previousMaxN, Threads.SpinLock())

	StringFolders = String[
		strFolder * "P2PKH/", # 1...
		strFolder * "P2SH/", # 3...
		strFolder * "Bech32/", # bc1q..
	]

	function String2ID(addr::String)::UInt32
		tagVersion = 1
		addrPrefix = addr[2:3] * "/"
		addrBody = addr[4:end]
		if addr[1] == '1'
			tagVersion = 1
		elseif addr[1] == 'b'
			tagVersion = 3
			addrPrefix = addr[5:6] * "/"
			addrBody = addr[7:end]
		elseif addr[1] == '3'
			tagVersion = 2
		else
			throw("error parsing $addr")
		end
		if !isdir(StringFolders[tagVersion] * addrPrefix)
			mkdir(StringFolders[tagVersion] * addrPrefix)
		end
		filePath = StringFolders[tagVersion] * addrPrefix * "sum"
		_len = length(addrBody)
		if isfile(filePath)
			f = open(filePath, "r")
			l = readline(f)
			while !isnothing(l)
				if length(l) > _len && l[1:_len] == addrBody
					v = parse(UInt32, split(l, '\t')[2])
					close(f)
					return v
				end
			end
			close(f)
		else
			touch(filePath)
		end
		# if new
			lock(MaxAddressNumber.dlock)
			n = MaxAddressNumber.id + 1
			f = open(filePath, "a")
			write(f, "$addrBody\t$id\n")
			close(f)
			MaxAddressNumber.id = n
			unlock(MaxAddressNumber.dlock)
		return n
	end

	function SetID(addr::String, id)::Nothing
		tagVersion = 1
		addrPrefix = addr[2:3] * "/"
		addrBody = addr[4:end]
		if addr[1] == '1'
			tagVersion = 1
		elseif addr[1] == 'b'
			tagVersion = 3
			addrPrefix = addr[5:6] * "/"
			addrBody = addr[7:end]
		elseif addr[1] == '3'
			tagVersion = 2
		else
			@warn "error parsing $addr"
			return nothing
		end
		if !isdir(StringFolders[tagVersion] * addrPrefix)
			mkdir(StringFolders[tagVersion] * addrPrefix)
		end
		filePath = StringFolders[tagVersion] * addrPrefix * "sum"
		f = open(filePath, "a")
		write(f, "$addrBody\t$id\n")
		close(f)
		if id > MaxAddressNumber.id
			MaxAddressNumber.id = id
		end
		return nothing
	end









