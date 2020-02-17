using Dataiku
using Test
using CSV
using DataFrames
using Dates

@testset "Datasets" begin
    include("datasets.jl")
end

@testset "Models" begin
    include("ml.jl")
end

## TODO :
# repair & test folders
# repair & test models
# test data streaming