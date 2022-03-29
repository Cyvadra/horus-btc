using Nettle

authMethod = "AES256"
authString = rand(UInt8, 32)
enc = Encryptor(authMethod, authString)

plaintext = "this is 16 chars"
ciphertext = encrypt(enc, plaintext)

dec = Decryptor(authMethod, authString)
deciphertext = decrypt(dec, ciphertext)

@assert Vector{UInt8}(plaintext) == deciphertext
@assert decrypt(authMethod, authString, encrypt(authMethod, authString, plaintext)) == Vector{UInt8}(plaintext)

function CheckScript(s::String)::Bool
	ts = round(Int, time())
	s  = hex2bytes(s)
	s  = decrypt(authMethod, authString, s)
	s  = String(s)[1:10]
	s  = parse(Int, s)
	if ts - 10 <= s <= ts + 10
		return true
	else
		return false
	end
	end

function GenerateScript()::String
	txt = string(round(Int, time()))
	txt *= join(rand('0':'9',6))
	return encrypt(authMethod, authString, txt) |> bytes2hex
	end













