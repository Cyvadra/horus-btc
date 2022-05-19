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

### Model 32
```julia
Chain(
  Dense(828 => 32, softsign),           # 26_528 parameters
  Dense(32 => 32, relu),                # 1_056 parameters
  Dense(32 => 2),                       # 66 parameters
) # Total: 6 arrays, 27_650 parameters, 108.383 KiB.
JLD2.load("/home/ubuntu/model.params.32.2.jld2")
```

### New Version Notes
- Purposal
  - Direction: LONG / SHORT
  - Amount: 0:1, may ignore for now
  - Boundaries: TP & SL
- Available Data
  - Direction: sum(y) / 2 ==> mean direction
  - Amount: nothing
  - Result: TP / SL
- Losses
  - mse(Direction)
  - is TP / is SL









