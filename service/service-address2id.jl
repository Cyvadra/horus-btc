

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
	strFolder * "Other/", # unexpected
]

function String2ID(addr::String)::UInt32
	tagVersion = 1
	addrPrefix = addr[2:4] * "/"
	addrBody = addr[5:end]
	if addr[1] == '1'
		tagVersion = 1
	elseif addr[1] == 'b'
		tagVersion = 3
		addrPrefix = addr[5:7] * "/"
		addrBody = addr[8:end]
	elseif addr[1] == '3'
		tagVersion = 2
	else
		tagVersion = 4
		addrPrefix = addr[1:2] * "/"
		addrBody = addr[3:end]
	end
	dirPath = StringFolders[tagVersion] * addrPrefix
	if !isdir(dirPath)
		mkdir(dirPath)
	end
	filePath = dirPath * "sum"
	if isfile(filePath)
		l = read(pipeline(
				`cat $filePath`,
				Cmd(`grep $addrBody`; ignorestatus=true),
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
		write(f, "$addrBody\t$n\n")
		close(f)
		MaxAddressNumber.id = n
		unlock(MaxAddressNumber.dlock)
	return n
	end

function String2IDSafe(addr::String)::UInt32
	tagVersion = 1
	addrPrefix = addr[2:4] * "/"
	addrBody = addr[5:end]
	if addr[1] == '1'
		tagVersion = 1
	elseif addr[1] == 'b'
		tagVersion = 3
		addrPrefix = addr[5:7] * "/"
		addrBody = addr[8:end]
	elseif addr[1] == '3'
		tagVersion = 2
	else
		tagVersion = 4
		addrPrefix = addr[1:2] * "/"
		addrBody = addr[3:end]
	end
	dirPath = StringFolders[tagVersion] * addrPrefix
	if !isdir(dirPath)
		mkdir(dirPath)
	end
	filePath = dirPath * "sum"
	if isfile(filePath)
		l = read(pipeline(
				`cat $filePath`,
				Cmd(`grep $addrBody`; ignorestatus=true),
			))
		if length(l) > 0
			s = String(l)
			s = s[findfirst('\t',s)+1:findfirst('\n',s)-1]
			return parse(UInt32, s)
		end
	end
	return UInt32(0)
	end

function SetID(addr, id)
	tagVersion = 1
	addrPrefix = addr[2:4] * "/"
	addrBody = addr[5:end]
	if addr[1] == '1'
		tagVersion = 1
	elseif addr[1] == 'b'
		tagVersion = 3
		addrPrefix = addr[5:7] * "/"
		addrBody = addr[8:end]
	elseif addr[1] == '3'
		tagVersion = 2
	else
		tagVersion = 4
		addrPrefix = addr[1:2] * "/"
		addrBody = addr[3:end]
	end
	dirPath = StringFolders[tagVersion] * addrPrefix
	if !isdir(dirPath)
		mkdir(dirPath)
	end
	filePath = dirPath * "sum"
	if !isfile(filePath)
		touch(filePath)
	end
	f = open(filePath, "a")
	write(f, "$addrBody\t$id\n")
	close(f)
	id = parse(Int, id)
	if id > MaxAddressNumber.id
		MaxAddressNumber.id = id
	end
	return nothing
	end

nothing







