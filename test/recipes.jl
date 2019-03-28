const recipeName = "test_recipe"

@testset "Recipes" begin

    body = Dict("name" => recipeName,
                "type" => "python")
    recipe = create_recipe(body, projectKey)
    @test recipe == DSSRecipe(recipeName, projectKey)

    settings = get_settings(recipe)
    @test settings["recipe"]["type"] == "python"
    @test settings["recipe"]["name"] == recipeName
    @test settings["recipe"]["projectKey"] == projectKey

    # @test set_settings(recipe, settings) == 

    metadata = get_metadata(recipe)
    @test length(metadata) == 3
    @test set_metadata(recipe, metadata)["msg"] == "Updated metadata $(projectKey).$(recipeName)"

    @test delete(recipe)["msg"] == "Deleted recipe $(projectKey).$(recipeName)"
end