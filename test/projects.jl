@testset "Projects" begin
    
    @testset "Settings" begin
        settings = Dataiku.get_settings(project)

        @test length(settings) == 4
        @test haskey(settings, "metrics")
        @test haskey(settings, "settings")
        @test haskey(settings, "metricsChecks")
        @test haskey(settings, "exposedObjects")

        @test length(settings["settings"]) == 17
        @test Dataiku.set_settings(project, settings) == nothing
    end

    @testset "API" begin
        metadata = Dataiku.get_metadata(project)

        @test length(metadata) == 4
        metadata["tags"] = ["test_tag1", "test_tag2"]
        @test Dataiku.set_metadata(project, metadata) == nothing

        tags = Dataiku.get_tags(project)
        @test length(tags["tags"]) == 2
        @test Dataiku.set_tags(project, tags) == nothing

        variables = Dataiku.get_variables(project)
        @test length(variables) == 2
        @test Dataiku.set_variables(project, variables) == nothing

        permissions = Dataiku.get_permissions(project)
        @test length(permissions) == 4
        @test Dataiku.set_permissions(project, permissions) == nothing
    end

    io = Dataiku.export_project(project)
    @test length(read(io)) > 3000

    try Dataiku.delete(DSSProject("NEW_"*projectKey)) catch end
    new_project = Dataiku.duplicate(project, "new_"*projectName, "NEW_"*projectKey)
    @test length(Dataiku.list_projects()) > 1
    @test Dataiku.delete(new_project) == nothing
end