struct DSSRecipe <: DSSObject
    project::DSSProject
    name::AbstractString
    DSSRecipe(name::AbstractString, project::DSSProject=get_current_project()) = new(project, name)
end

macro recipe_str(str)
    createobject(DSSRecipe, str)
end

export @recipe_str
export DSSRecipe

list_recipes(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/recipes/")

get_definition_and_payload(recipe::DSSRecipe) = request_json("GET", "projects/$(recipe.project.key)/recipes/$(recipe.name)")

# Doesnt work with empty or without payloads?
set_definition_and_payload(recipe::DSSRecipe, settings::AbstractDict) = request_json("PUT", "projects/$(recipe.project.key)/recipes/$(recipe.name)", settings)

get_metadata(recipe::DSSRecipe) = request_json("GET", "projects/$(recipe.project.key)/recipes/$(recipe.name)/metadata")
set_metadata(recipe::DSSRecipe, metadata::AbstractDict) = request_json("PUT", "projects/$(recipe.project.key)/recipes/$(recipe.name)/metadata", metadata)

get_status(recipe::DSSRecipe) = request_json("GET", "projects/$(recipe.project.key)/recipes/$(recipe.name)/status")

create_recipe(name, type, project::DSSProject=get_current_project(); kwargs...) =
    create_recipe(Dict("name" => name,"type" => type), project; kwargs...)

function create_recipe(recipe::AbstractDict, project::DSSProject=get_current_project(); creationSettings::AbstractDict=Dict())
    recipe["projectKey"] = project.key
    body = Dict(
        "recipePrototype"  => recipe,
        "creationSettings" => creationSettings
    )
    request_json("POST", "projects/$(project.key)/recipes/", body)
    DSSRecipe(recipe["name"], project)
end

delete(recipe::DSSRecipe) = request_json("DELETE", "projects/$(recipe.project.key)/recipes/$(recipe.name)")