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
	s  = decrypt(authMethod, authString, Vector{UInt8}(s))
	s  = parse(Int, s)
	if ts - 10 <= s <= ts + 10
		return true
	else
		return false
	end
	end















