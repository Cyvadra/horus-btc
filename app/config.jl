
rootPath          = "/mnt/spare/horus-storage/rolling"
ramPath           = "/tmp"

# tsFile            = "$rootPath/bitcore/BlockTimestamps.dict.jld2"
cacheMarket       = "$ramPath/market.json"
# fileAddressString = "$rootPath/bitcore/addr.latest.txt"
logAddressString  = "$rootPath/addr.runtime.log"
jldAddressIdFile  = "$rootPath/addr.hashdict.jld2"
jldAddressBalance = "$rootPath/addr.balance.jld2"
folderAddressDB   = "$ramPath/AddressServiceDB-v3/"
folderStructures  = "$ramPath/julia-cache/"
folderMarket      = "$rootPath/BTC_USDT_1m/"
folderResults     = "$rootPath/results-flexible-v3/"
folderBlockPairs  = "$rootPath/block-timestamp/"
folderTransactions= "$rootPath/transactions-btc/"

@assert isfile( logAddressString )
@assert isfile( jldAddressIdFile )
@assert isfile( jldAddressBalance )
# @assert isdir( folderAddressDB )
@assert isdir( folderMarket )
@assert isdir( folderResults )
@assert isdir( folderBlockPairs )
@assert isdir( folderTransactions )

