
include("./config.jl");
include("./utils.jl");
include("./service-block_timestamp.jl");
include("./service-FinanceDB.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");
include("./functions-ma.jl");
include("./client-config.jl");

using Dates
using Statistics
using Flux
using ProgressMeter

TableResults.Open(true)
@show GetLastResultsID()

numMa    = 16 # 48h
postSecs = 10800 # predict 3h
tmpSyms  = ResultCalculations |> fieldnames |> collect

function ret2dict(tmpRet::Vector{ResultCalculations})::Dict{String,Vector}
	anoRet   = Dict{String,Vector}()
	for s in tmpSyms
		if occursin("Billion", string(s))
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet) .* 1e9
		else
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet)
		end
	end
	return anoRet
	end

function GenerateY(ts, postSecs::Int)
	ratioSL = 1.05
	ratioTP = 0.95
	c = middle(GetBTCCloseWhen(ts-postSecs:ts))
	h = reduce(max, GetBTCHighWhen(ts+60:ts+postSecs))
	l = reduce(min, GetBTCLowWhen(ts+60:ts+postSecs))
	h = 100*abs(h - c) / c
	l = 100*abs(c - l) / c
	return [h, -l]
	end
function GenerateY(anoRet::Dict{String,Vector})
	tsList = anoRet["timestamp"]
	return hcat([ GenerateY(ts, postSecs) for ts in tsList ]...)' |> collect
	end

function GenerateX(anoRet::Dict{String,Vector})::Matrix{Float32}
	sequences = Vector[]
	for k in dnnList
		push!(sequences,
			Vector{Float32}(middlefit(anoRet[k], 2numMa))
			)
	end
	return hcat(sequences...)
	end

fromDate  = DateTime(2019,3,1,0)
toDate    = DateTime(2022,3,31,0)
anoRet    = GenerateWindowedViewH3(fromDate, toDate) |> ret2dict
oriX = GenerateX(anoRet)[2numMa:end, :]
oriY = GenerateY(anoRet)[2numMa:end, :]

X = [ vcat(oriX[i-numMa:i,:]...) for i in numMa+1:size(oriX)[1] ];
Y = [ oriY[i,:] for i in numMa+1:size(oriY)[1] ];

@showprogress for i in 1:5
	anoRet  = GenerateWindowedViewH3(
		fromDate + Minute(30i),
		toDate + Minute(30i)
		) |> ret2dict
	tmpX = GenerateX(anoRet)[numMa:end, :]
	tmpY = GenerateY(anoRet)[numMa:end, :]
	append!(X, [ vcat(tmpX[i-numMa:i,:]...) for i in numMa+1:size(tmpX)[1] ])
	append!(Y, [ tmpY[i,:] for i in numMa+1:size(tmpY)[1] ])
	@assert length(X) == length(Y)
end




# Prepare Data
tmpMidN = round(Int, length(X)*0.8)
tmpIndexes = sortperm(rand(tmpMidN))
training_x = deepcopy(X[tmpIndexes])
training_y = deepcopy(Y[tmpIndexes])
test_x = deepcopy(X[tmpMidN+1:end])
test_y = deepcopy(Y[tmpMidN+1:end])

yLength   = length(Y[end])
inputSize = length(X[1])
data      = zip(training_x, training_y)

nThrottle  = 30

m = Chain(
			Dense(inputSize, inputSize, relu),
			Dense(inputSize, 256, tanh_fast),
			Dense(256, yLength),
		)
ps = Flux.params(m);

opt        = ADADelta();
tx, ty     = (test_x[15], test_y[15]);
evalcb     = () -> @show loss(tx, ty);
loss(x, y) = Flux.Losses.mse(m(x), y);

tmpLen     = length(training_y[1]);
tmpBase    = [ mean(map(x->x[i], training_y)) for i in 1:tmpLen ];
tmpLoss    = mean([ Flux.Losses.mse(tmpBase, test_y[i]) for i in 1:length(test_y) ]);
@info "Baseline Loss: $tmpLoss"


prev_loss = [ Flux.Losses.mse(m(test_x[i]), test_y[i]) for i in 1:length(test_x) ] |> mean;
ps_saved  = deepcopy(collect(ps));
@info "Initial Loss: $prev_loss"
nCounter  = 0;
while true
	# train
	@info "$nCounter/∞"
	Flux.train!(loss, ps, data, opt; cb = Flux.throttle(evalcb, nThrottle))
	nCounter += 1
	# current loss
	this_loss = [ Flux.Losses.mse(m(test_x[i]), test_y[i]) for i in 1:length(test_x) ] |> mean
	@info "latest loss $this_loss"
	# record
	if this_loss < 0.98*prev_loss
		ps_saved = deepcopy(collect(ps));
		prev_loss = this_loss
	end
end


