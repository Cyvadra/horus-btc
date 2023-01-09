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
BalanceCounterMatrix = Matrix{Int32}(undef, 780000, 10000);
BalanceAmountMatrix = Matrix{Float64}(undef, 780000, 10000);
BalanceCounterMatrix .= 0
BalanceAmountMatrix .= 0.0
AddressBalanceList = zeros(Float64, round(Int, 1.28e9))

# define procedure
function locateChunk(v::Float64)
	p = findfirst(x->x>=v, BALANCE_CHUNKS)
	isnothing(p) ? length(BALANCE_CHUNKS) : p
	end

@showprogress for n in 1:771111
	# mint
	currentCoins = GetCoinsByMintHeight(n)
	a = ReadID.(map(x->x["address"], currentCoins))
	b = bitcoreInt2Float64.(map(x->x["value"], currentCoins))
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
	currentCoins = GetCoinsBySpentHeight(n)
	a = ReadID.(map(x->x["address"], currentCoins))
	b = bitcoreInt2Float64.(map(x->x["value"], currentCoins))
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
