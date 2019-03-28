using Dataiku
using Test

const projectName = "test_project"
const projectKey = uppercase(projectName)

try Dataiku.delete(DSSProject(projectKey)) catch end
try Dataiku.delete(DSSProject("NEW_"*projectKey)) catch end
project = Dataiku.create_project(projectName)

include("datasets.jl")
include("projects.jl")
include("recipes.jl")

delete(project)