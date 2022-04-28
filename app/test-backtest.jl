
include("./config.jl");
include("./cache-generated.jl");
include("./service-block_timestamp.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");
include("./functions-ma.jl");

using Dates

TableResults.Open(true)
@show GetLastResultsID()

fromDate = DateTime(2019,3,1,1)
toDate   = DateTime(2022,3,31,1)

GenerateWindowedViewH2(fromDate, toDate)




















