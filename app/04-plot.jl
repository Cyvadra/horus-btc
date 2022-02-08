using Plots, Plotly
using JLD2
using Statistics
using DataFrames

plotly()
Plots.plot(rand(100))

function normalize(x::Vector)::Vector
	m = Statistics.mean(x)
	return x ./ m
	end

function Vector2DataFrame(v::Vector)::DataFrame
	dataType = typeof(v[1])
	dataSubTypes  = dataType.types
	dataSubNames  = fieldnames(dataType)
	dataNumFields = length(dataSubTypes)
	df = DataFrame([
			dataSubNames[i] => map(x->getfield(x,i), v) for i in 1:dataNumFields
		])
	return df
	end

function pretreat(v::Vector)
	x = log2.(v)
	m = Statistics.mean(x)
	return x ./ m
	end

function PlotDF(df::DataFrame, xName::String="timestamp")::Plots.Plot{Plots.PlotlyBackend}
	xrow     = df[:,xName]
	colNames = string.(collect(keys(copy(df[1,:]))))
	filter!(x->x!==xName, colNames)
	# Plots.plot( xrow, log2.(df[:,1].+1); label=colNames[1] )
	Plots.plot( xrow, log2.(df[:,1].+1); color="blue", alpha=0.2 );
	for n in colNames[2:end]
		Plots.plot!( xrow, log2.(df[:,n].+1); color="blue", alpha=0.2 )
	end
	end

Plots.plot!( d.Timestamps[][1:2:end], 
	log2.(d.Close[][1:2:end]);
	label="market", color="green" )

marketData = load("./btc_usdt.market.jld2")

numRows = nrow(df)
xs = marketData["D1"].Timestamps.x[1:numRows]
ys = marketData["D1"].Close.x[1:numRows]
Plots.plot!(xs, pretreat(ys); label="market", color="green")




