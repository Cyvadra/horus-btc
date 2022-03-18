using Plots, Plotly; plotly(); Plots.plot(rand(100));
using JLD2

# JLD2.load(...)

Plots.plot([]);

[ Plots.plot!(map(x->x[i], predict); label="predict"*string(i), color="blue", alpha=0.6) for i in 1:length(predict[1]) ];

[ Plots.plot!(map(x->x[i], actual); label="actual"*string(i), color="red", alpha=0.6) for i in 1:length(actual[1]) ];

Plots.plot!()


