
include("./config.jl");
include("./utils.jl");
include("./cache-generated.jl");
include("./service-block_timestamp.jl");
include("./service-FinanceDB.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");
include("./functions-ma.jl");
include("./client-config.jl");

using Dates
using Statistics
using Flux

TableResults.Open(true)
@show GetLastResultsID()

numMa    = 12 # 24h
postSecs = 10800 # predict 3h
tmpSyms  = ResultCalculations |> fieldnames |> collect

function GenerateY(ts, postSecs::Int)
	ret = Float32[0.0, 0.0, 0.0]
	lastH = GetBTCHighWhen(ts)
	lastL = GetBTCLowWhen(ts)
	h = reduce(max, GetBTCHighWhen(ts+60:ts+postSecs))
	l = reduce(min, GetBTCLowWhen(ts+60:ts+postSecs))
	c = Statistics.middle(GetBTCCloseWhen(ts:ts+postSecs))
	dh = h - lastH
	dl = lastL - l
	if dh > dl
		ret[1] = 1.0
		ret[2] = (h - lastH) / lastH
		ret[3] = (lastH - l) / lastH
	else
		ret[1] = -1.0
		ret[2] = (lastL - l) / lastL
		ret[3] = (h - lastL) / lastL
	end
	return ret
	end

function GenerateSequences(tmpRet::Vector{ResultCalculations})::Matrix{Float32}
	anoRet   = Dict{String,Vector}()
	for s in tmpSyms
		if occursin("Billion", string(s))
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet) .* 1e9
		else
			anoRet[string(s)] = map(x->getfield(x,s), tmpRet)
		end
	end
	tsList    = anoRet["timestamp"]
	baseList  = anoRet["amountTotalTransfer"]
	sequences = Vector[]
	y = hcat([ GenerateY(ts, postSecs) for ts in tsList ]...)'
	for k in dnnList
		tmpList = anoRet[k] ./ baseList
		tmpBase = ma(tmpList, numMa)
		tmpList = histofit(tmpList ./ tmpBase)
		push!(sequences,
			Vector{Float32}(tmpList)
			)
	end
	return hcat(y, sequences...)
	end

fromDate  = DateTime(2019,3,1,0)
toDate    = DateTime(2022,3,31,0)
@time res = GenerateWindowedViewH3(fromDate, toDate) |> GenerateSequences
for i in 1:5
	res = vcat(res,
		GenerateWindowedViewH3(fromDate + Minute(30i), toDate + Minute(30i)) |> GenerateSequences
		)
end






# Training

X = res[:, 4:end];
Y = res[:, 1:3];
X = [X[i,:] for i in 1:size(X)[1]];
Y = [Y[i,:] for i in 1:size(Y)[1]];
tmpMidN = round(Int, length(X)*0.8)
tmpIndexes = sortperm(rand(tmpMidN))
training_x = deepcopy(X[tmpIndexes])
training_y = deepcopy(Y[tmpIndexes])
test_x = deepcopy(X[tmpMidN+1:end])
test_y = deepcopy(Y[tmpMidN+1:end])

yLength   = length(Y[end])
inputSize = length(X[1])
data      = zip(training_x, training_y)

nTolerance = 20
minEpsilon = 1e-15
nThrottle  = 15
modelWidth = 1024

m = Chain(
		Dense(inputSize, modelWidth),
		Dense(modelWidth, modelWidth),
		Dense(modelWidth, yLength),
	)
ps = params(m);

opt        = ADAM();
tx, ty     = (test_x[15], test_y[15]);
evalcb     = () -> @show loss(tx, ty);
loss(x, y) = Flux.Losses.mse(m(x), y);

tmpLen     = length(training_y[1]);
tmpBase    = [ mean(map(x->x[i], training_y)) for i in 1:tmpLen ];
tmpLoss    = mean([ Flux.Losses.mse(tmpBase, training_y[i]) for i in 1:length(training_y) ]);
@info "Baseline Loss: $tmpLoss"


prev_loss = [ Flux.Losses.mse(m(training_x[i]), training_y[i]) for i in 1:length(training_x) ] |> mean;
ps_saved  = deepcopy(collect(ps));
@info "Initial Loss: $prev_loss"
nCounter  = 0;
tmpFlag   = true;
while true
	Flux.train!(loss, ps, data, opt; cb = Flux.throttle(evalcb, nThrottle))
	this_loss = [ Flux.Losses.mse(m(training_x[i]), training_y[i]) for i in 1:length(training_x) ] |> mean
	if this_loss < 0.95 * prev_loss
		ps_saved  = deepcopy(collect(ps))
		prev_loss = this_loss
		println()
		@info "New best loss $prev_loss"
		nCounter  = 0
		tmpFlag   = true
	else
		@info "loop $nCounter/$nTolerance, loss $this_loss"
		nCounter += 1
		if nCounter > nTolerance
			if tmpFlag == false
				e = opt.epsilon * 1.25
				println()
				@info "Increase epsilon to $e"
				opt.epsilon *= 1.25
				nCounter = 0
			elseif opt.epsilon > minEpsilon
				e = opt.epsilon/2
				println()
				@info "Updated epsilon to $e"
				opt.epsilon /= 2
				nCounter = 0
				nTolerance += 2
				tmpFlag  = false
			else
				@info "Done!"
				break
			end
		end
	end
end


