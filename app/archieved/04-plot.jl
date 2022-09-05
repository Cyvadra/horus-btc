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

function PlotDF(df::DataFrame, xName::String="timestamp")
	xrow     = df[:,xName]
	colNames = string.(collect(keys(copy(df[1,:]))))
	filter!(x->x!==xName, colNames)
	# Plots.plot( xrow, log2.(df[:,1].+1); label=colNames[1] )
	Plots.plot( xrow, normalize(df[:,1].+1); color="blue", alpha=0.2 );
	for n in colNames[2:end]
		Plots.plot!( xrow, normalize(df[:,n].+1); color="blue", alpha=0.2 )
	end
	end

Plots.plot!( d.Timestamps[][1:2:end], 
	log2.(d.Close[][1:2:end]);
	label="market", color="green" )

marketData = load("./btc_usdt.market.jld2")

tsFirst = df[1, :timestamp]
tsLast  = df[end, :timestamp]

numRows = nrow(df)
tmpInds = findfirst(x->x>=tsFirst, marketData["H3"].Timestamps.x):findlast(x->x<=tsLast, marketData["H3"].Timestamps.x)
xs = marketData["H3"].Timestamps.x[tmpInds]
ys = marketData["H3"].Close.x[tmpInds]
Plots.plot!(xs, normalize(ys); label="market", color="green")




