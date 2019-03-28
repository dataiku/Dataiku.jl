struct DSSRecipe <: DSSObject
    name::AbstractString
    projectKey::AbstractString
    DSSRecipe(name::AbstractString, projectKey=get_projectKey()) = new(name, projectKey)
end

macro recipe_str(str)
    createobject(DSSRecipe, str)
end

export @recipe_str
export DSSRecipe

list_recipes(projectKey=get_projectKey()) = request("GET", "projects/$(projectKey)/recipes/")

get_settings(recipe::DSSRecipe) = request("GET", "projects/$(recipe.projectKey)/recipes/$(recipe.name)")

# Doesnt work with empty payloads?
set_settings(recipe::DSSRecipe, settings::AbstractDict) = request("PUT", "projects/$(recipe.projectKey)/recipes/$(recipe.name)")

get_metadata(recipe::DSSRecipe) = request("GET", "projects/$(recipe.projectKey)/recipes/$(recipe.name)/metadata")

set_metadata(recipe::DSSRecipe, metadata::AbstractDict) = request("PUT", "projects/$(recipe.projectKey)/recipes/$(recipe.name)/metadata", metadata)


# should we add DSSRecipeCreator ?
function create_recipe(recipe::AbstractDict, projectKey=get_projectKey(); creationSettings::AbstractDict=Dict())
    recipe["projectKey"] = projectKey
    body = Dict(
        "recipePrototype"  => recipe,
        "creationSettings" => creationSettings
    )
    request("POST", "projects/$(projectKey)/recipes/", body)
    return DSSRecipe(recipe["name"], projectKey)
end

delete(recipe::DSSRecipe) = request("DELETE", "projects/$(recipe.projectKey)/recipes/$(recipe.name)")

export create_recipe