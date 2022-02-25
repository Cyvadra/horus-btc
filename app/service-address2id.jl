

strFolder = "/mnt/data/AddressServiceString/"
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
	if isfile(filePath)
		l = read(pipeline(
				`cat $filePath`,
				`grep $addrBody`,
			))
		if length(l) > 0
			s = String(l)
			s = s[findfirst('\t',s)+1:findfirst('\n',s)-1]
			return parse(UInt32, s)
		end
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

function String2IDSafe(addr::String)::UInt32
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
	if isfile(filePath)
		l = read(pipeline(
				`cat $filePath`,
				`grep $addrBody`,
			))
		if length(l) > 0
			s = String(l)
			s = s[findfirst('\t',s)+1:findfirst('\n',s)-1]
			return parse(UInt32, s)
		end
	end
	throw("$addr not found")
	end

function UpsertAddrID(addr::String, id)::Nothing
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
	if isfile(filePath)
		l = read(pipeline(
				`cat $filePath`,
				`grep $addrBody`,
			))
		if length(l) > 0
			s = String(l)
			s = s[findfirst('\t',s)+1:findfirst('\n',s)-1]
			return parse(UInt32, s)
		end
	else
		touch(filePath)
	end
	f = open(filePath, "a")
	write(f, "$addrBody\t$id\n")
	close(f)
	if id > MaxAddressNumber.id
		MaxAddressNumber.id = id
	end
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









