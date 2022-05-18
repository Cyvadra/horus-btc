using HTTP
using JSON

BINANCE_LOCAL_ENDPOINT = "http://127.0.0.1:8023/"

function CreateOrder(direction::String, quantity::Float32)
	methodString = "createOrder"
	url = BINANCE_LOCAL_ENDPOINT * methodString * "?direction=$direction&quantity=$quantity"
	return JSON.Parser.parse(HTTP.get(url).body)
	end





















