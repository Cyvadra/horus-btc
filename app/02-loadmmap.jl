using BSON, JSON
using JLD2, DataFrames

# Config
	dataFolder   = "/mnt/data/bitcore/"
	addrDictPath = dataFolder * "addr.latest.txt"
	counterFile  = dataFolder * "counter"
	# TxStateDF    = JLD2.load(dataFolder * "TxStateDF.jld2")["TxStateDF"]
	TxRowsDF     = JLD2.load(dataFolder * "TxRowsDF.working.jld2")["TxRowsDF"]
# 	GlobalStat   = JSON.Parser.parse(readline(counterFile))
# 	@show GlobalStat

# # Valid data
# 	@assert nrow(TxStateDF) + 1 == GlobalStat["PointerTx"]
# 	@assert nrow(TxRowsDF) + 1 == GlobalStat["PointerTxRows"]
