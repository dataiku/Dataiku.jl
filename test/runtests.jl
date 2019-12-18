using Dataiku
using Test
using CSV
using DataFrames
using Dates

const datasetName = "test_dataset"
const projectName = "test_project"
const projectKey = Dataiku.create_projectKey(projectName)

project = DSSProject(projectKey)

try Dataiku.delete(project) catch end
project = Dataiku.create_project(projectName)

df = CSV.read(joinpath(dirname(pathof(Dataiku)), "..", "test", "data", "colis_80.csv")) |> DataFrame
df.Date_parsed = map(df.Date_parsed) do a
    DateTime(a, dateformat"yyyy-mm-ddT00:00:00.000Z")
end
df.Date = map(df.Date) do a
    string(a)
end

Dataiku.set_current_project(project)

dataset = Dataiku.create_dataset(datasetName, project)
Dataiku.write_with_schema(dataset, df)
include("projects.jl")
include("datasets.jl")
include("ml.jl")
include("scenarios.jl")
include("recipes.jl")

@test Dataiku.delete(dataset)["msg"] == "Deleted dataset $projectKey.$datasetName"

Dataiku.delete(project)