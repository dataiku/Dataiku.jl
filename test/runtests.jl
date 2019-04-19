using Dataiku
using Test
using CSVFiles
using DataFrames
using Dates

const datasetName = "test_dataset"
const projectName = "test_project"
const projectKey = Dataiku.create_projectKey(projectName)

project = DSSProject(projectKey)

try Dataiku.delete(project) catch end
project = Dataiku.create_project(projectName)

df = load(joinpath(dirname(pathof(Dataiku)), "..", "test/data/colis_80.csv")) |> DataFrame
df[:Date] = map(df[:Date]) do date
    Dates.format(date, "yyyy-mm-dd")
end

Dataiku.set_current_project(project)

try Dataiku.delete(DSSDataset(datasetName)) catch end
dataset = Dataiku.create_dataset(datasetName, project)
Dataiku.write_with_schema(dataset, df)
include("datasets.jl")
include("ml.jl")

include("projects.jl")
include("recipes.jl")

@test Dataiku.clear_data(dataset) == []
@test Dataiku.delete(dataset)["msg"] == "Deleted dataset $projectKey.$datasetName"

Dataiku.delete(project)