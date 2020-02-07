using Dataiku
using Test
using CSV
using DataFrames
using Dates

try Dataiku.delete(project"TEST_PROJECT") catch end
project = Dataiku.create_project("test_project")

Dataiku.set_current_project(project)

dataset = Dataiku.create_dataset("test_dataset", project)

include("datasets.jl")
# include("ml.jl")

@test Dataiku.delete(dataset)["msg"] == "Deleted dataset TEST_PROJECT.test_dataset"

Dataiku.delete(project)