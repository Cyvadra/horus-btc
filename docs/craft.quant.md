## Quant notes.

### A trade order consists of:
- Direction ==> long / short
- Amount ==> position
- Stop Loss / Take Profit ==> if it's possible

### A trade order results in:
- Realized amount

#### Model 8
> numPrev = 12 # 36h
> numMiddlefit = 24 # 72h
```julia
m = Chain(
  Dense(828 => 8, tanh_fast),           # 6_632 parameters
  Dense(8 => 4, relu),                  # 36 parameters
  Dense(4 => 2),                        # 10 parameters
) # Total: 6 arrays, 6_678 parameters, 26.461 KiB.
JLD2.save("/mnt/data/tmp/model.params.8.jld2", "ps", collect.(ps) |> deepcopy)
```

### Model 64
> numPrev = 12 # 36h
> numMiddlefit = 24 # 72h
```julia
m = Chain(
  Dense(828 => 64, tanh_fast),          # 53_056 parameters
  Dense(64 => 8, relu),                 # 520 parameters
  Dense(8 => 2),                        # 18 parameters
) # Total: 6 arrays, 53_594 parameters, 856 bytes.
JLD2.save("/home/ubuntu/model.params.64.jld2", "ps", cpu.(collect.(ps)) |> deepcopy)
```
