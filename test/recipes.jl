const recipeName = "test_recipe"

@testset "Recipes" begin

    body = Dict("name" => recipeName,
                "type" => "python")
    recipe = create_recipe(body, project)
    @test recipe == DSSRecipe(recipeName, project)

    definition = get_definition(recipe)
    @test definition["recipe"]["type"] == "python"
    @test definition["recipe"]["name"] == recipeName
    @test definition["recipe"]["projectKey"] == projectKey

    metadata = get_metadata(recipe)
    @test length(metadata) == 3
    @test set_metadata(recipe, metadata)["msg"] == "Updated metadata $(full_name(recipe))"

    @test delete(recipe)["msg"] == "Deleted recipe $(full_name(recipe))"
end