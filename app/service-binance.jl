using HTTP
using JSON

BINANCE_LOCAL_ENDPOINT = "http://127.0.0.1:8023/"
DEFAULT_RET_STRING = "fine"

function CreateOrder(direction::String, quantity::Float32, stop_loss::Float64, take_profit::Float64)
	methodString = "createOrder"
	url = BINANCE_LOCAL_ENDPOINT * methodString * "?direction=$direction&quantity=$quantity&stop_loss=$stop_loss&take_profit=$take_profit"
	s = String(HTTP.get(url).body)
	if s !== DEFAULT_RET_STRING
		@warn s
	end
	return nothing
	end

function CloseAllOrders()
	methodString = "closeAllOrders"
	url = BINANCE_LOCAL_ENDPOINT * methodString
	s = String(HTTP.get(url).body)
	if s !== DEFAULT_RET_STRING
		@warn s
	end
	return nothing
	end



















