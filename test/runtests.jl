using Dataiku
using Test
using CSV
using DataFrames
using Dates

@testset "Datasets" begin
    include("datasets.jl")
end

@testset "Folders" begin
    include("folders.jl")
end

@testset "Models" begin
    include("ml.jl")
end
