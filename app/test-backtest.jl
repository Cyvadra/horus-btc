
include("./config.jl");
include("./service-block_timestamp.jl");
include("./middleware-results-flexible.jl");
include("./functions-generate_window.jl");

TableResults.Open(true)
@show GetLastResultsID()

using Dates

fromDate = DateTime(2019,3,1,1)
toDate   = DateTime(2022,3,31,1)

GenerateWindowedViewH2(fromDate, toDate)




















