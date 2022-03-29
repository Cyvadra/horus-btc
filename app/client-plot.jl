include("./auth.jl")

using HTTP
using JSON
using PlotlyJS

serviceURL = "http://localhost:8080/sequence"

HTTP.get("http://baidu.com") # precompile HTTP

s = GenerateScript()
d = String(HTTP.get(serviceURL*"?session=$s").body) |> JSON.Parser.parse

