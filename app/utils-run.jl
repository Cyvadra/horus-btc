
function exec(cmd::AbstractString)
	tmpHash = bytes2hex(rand(UInt8,6)) * bytes2hex(rand(UInt8,3))
	tmpFileCommand = "/tmp/julia.run." * tmpHash * ".jl"
	tmpFileCache   = "/tmp/julia.run." * tmpHash * ".out"
	tmpFileErr     = "/tmp/julia.run." * tmpHash * ".err"
	write(tmpFileCommand, cmd * " 1>$tmpFileCache 2>$tmpFileErr")
	try
		run(`bash $tmpFileCommand`)
	catch e
		@warn e
		@warn "Command: $cmd; failed, exiting..."
		if isfile(tmpFileCache)
			rm(tmpFileCache)
		end
		if isfile(tmpFileErr)
			@warn String(read(tmpFileErr))
			rm(tmpFileErr)
		end
		rm(tmpFileCommand)
		throw(cmd)
	end
	rm(tmpFileCommand)
	if isfile(tmpFileCache)
		strRet = String(read(tmpFileCache)[1:end-1])
		rm(tmpFileCache)
		rm(tmpFileErr)
		return strRet
	elseif isfile(tmpFileErr)
		strRet = String(read(tmpFileErr))
		rm(tmpFileErr)
		throw(strRet)
	else
		throw(cmd)
	end
	end

