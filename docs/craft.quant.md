## Quant notes.

### A trade order consists of:
- Direction ==> long / short
- Amount ==> position
- Stop Loss / Take Profit ==> if it's possible

### A trade order results in:
- Realized amount

#### Model 256
> numMa    = 16 # 48 h
```julia
m = Chain(
			Dense(1173, 1173, relu),
			Dense(1173, 256, tanh_fast),
			Dense(256, 2),
		) |> gpu
ps = Flux.params
```

