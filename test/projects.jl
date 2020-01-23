@testset "Projects" begin
    
    @testset "Settings" begin
        settings = Dataiku.get_settings(project)
        @test haskey(settings, "settings")
        @test isnothing(Dataiku.set_settings(project, settings))
    end

    @testset "API" begin
        metadata = Dataiku.get_metadata(project)

        @test length(metadata) == 4
        metadata["tags"] = ["test_tag1", "test_tag2"]
        @test isnothing(Dataiku.set_metadata(project, metadata))

        tags = Dataiku.get_tags(project)
        @test length(tags["tags"]) == 2
        @test isnothing(Dataiku.set_tags(project, tags))

        variables = Dataiku.get_variables(project)
        @test length(variables) == 2
        @test isnothing(Dataiku.set_variables(project, variables))
    end
    try Dataiku.delete(DSSProject("NEW_"*projectKey)) catch end
    new_project = Dataiku.duplicate(project, "new_"*projectName, "NEW_"*projectKey)
    @test length(Dataiku.list_projects()) > 1
    @test isnothing(Dataiku.delete(new_project))
end
