const recipeName = "test_recipe"

@testset "Recipes" begin
    recipe = Dataiku.create_recipe(recipeName, "python", project)
    @test recipe == DSSRecipe(recipeName, project)

    definition = Dataiku.get_definition(recipe)
    @test definition["recipe"]["type"] == "python"
    @test definition["recipe"]["name"] == recipeName
    @test definition["recipe"]["projectKey"] == projectKey

    metadata = Dataiku.get_metadata(recipe)
    @test metadata["tags"] == []
    @test Dataiku.set_metadata(recipe, metadata)["msg"] == "Updated metadata $(full_name(recipe))"

    status = Dataiku.get_status(recipe)
    @test haskey(status, "engines")
    @test Dataiku.delete(recipe)["msg"] == "Deleted recipe $(full_name(recipe))"
end