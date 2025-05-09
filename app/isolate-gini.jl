include("./utils.jl");
include("./config.jl");
include("./service-address2id.jl");
include("./service-FinanceDB.jl");
include("./service-mongo.jl");

using JLD2
BALANCE_CHUNKS = JLD2.load("/mnt/data/bitcore/balance.chunks.jld2")["BALANCE_CHUNKS"]

#= definitions:
	[ boundary[i], boundary[i+1] )
=#

# define results
BalanceCounterMatrix = Matrix{Int32}(undef, 999999, length(BALANCE_CHUNKS));
BalanceAmountMatrix = Matrix{Float32}(undef, 999999, length(BALANCE_CHUNKS));
BalanceCounterMatrix .= 0
BalanceAmountMatrix .= 0.0
AddressBalanceList = zeros(Float64, round(Int, 1.88e9))

# define procedure
function locateChunk(v::Float64)
	# actually +1
	v < BALANCE_CHUNKS[end] ? findfirst(x->x>=v, BALANCE_CHUNKS) : length(BALANCE_CHUNKS)
	end

@showprogress for n in 1:GetLastResultsID()
	allCoins = TableTx.GetRow(GetSeqBlockCoinsRange(n))
	# mint
	currentCoins = filter(x->x.amount > 0.0, allCoins)
	a = map(x->x.addressId, currentCoins)
	b = map(x->x.amount, currentCoins)
	tmpChunks = locateChunk.(AddressBalanceList[a])
	for i in 1:length(tmpChunks)
		BalanceCounterMatrix[n, tmpChunks[i]] -= 1
		BalanceAmountMatrix[n, tmpChunks[i]] -= AddressBalanceList[a[i]]
	end
	AddressBalanceList[a] .+= b
	tmpChunks = locateChunk.(AddressBalanceList[a])
	for i in 1:length(tmpChunks)
		BalanceCounterMatrix[n, tmpChunks[i]] += 1
		BalanceAmountMatrix[n, tmpChunks[i]] += AddressBalanceList[a[i]]
	end
	# spent
	currentCoins = filter(x->x.amount < 0.0, allCoins)
	a = map(x->x.addressId, currentCoins)
	b = abs.( map(x->x.amount, currentCoins) )
	tmpChunks = locateChunk.(AddressBalanceList[a])
	for i in 1:length(tmpChunks)
		BalanceCounterMatrix[n, tmpChunks[i]] -= 1
		BalanceAmountMatrix[n, tmpChunks[i]] -= AddressBalanceList[a[i]]
	end
	AddressBalanceList[a] .-= b # difference here
	tmpChunks = locateChunk.(AddressBalanceList[a])
	for i in 1:length(tmpChunks)
		BalanceCounterMatrix[n, tmpChunks[i]] += 1
		BalanceAmountMatrix[n, tmpChunks[i]] += AddressBalanceList[a[i]]
	end
	end

function gini(wagedistarray::Matrix)
	Swages = cumsum(wagedistarray[:,1].*wagedistarray[:,2])
	Gwages = Swages[1]*wagedistarray[1,2] +
		sum(
			wagedistarray[2:end,2] .* 
			(Swages[2:end]+Swages[1:end-1])
		)
	return 1 - Gwages/Swages[end]
end

function labGiniBase(n)
	a = reduce(+, BalanceCounterMatrix[1:n,:]; dims=1)[:]
	b = reduce(+, BalanceAmountMatrix[1:n,:]; dims=1)[:]
	a = a ./ -a[1]
	gini( hcat(b[2:end], a[2:end]) )
	end

a = reduce(+, BalanceCounterMatrix[1:1,:]; dims=1)[:];
b = reduce(+, BalanceAmountMatrix[1:1,:]; dims=1)[:];
retListGini = zeros(Float64, size(BalanceAmountMatrix)[1]);
retListMean = zeros(Float64, size(BalanceAmountMatrix)[1]);
@showprogress for i in 2:793422
	global a
	global b
	a = a .+ BalanceCounterMatrix[i,:]
	b = b .+ BalanceAmountMatrix[i,:]
	retListGini[i] = gini( hcat(b[2:end-3600], a[2:end-3600] ./ (-a[1]-sum(a[end-3600:end])) ) )
	retListMean[i] = sum(b[2:end]) / -a[1]
	end

