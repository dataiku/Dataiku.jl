@testset "Projects" begin
    
    @testset "Settings" begin
        settings = get_settings(project)

        @test length(settings) == 4
        @test haskey(settings, "metrics")
        @test haskey(settings, "settings")
        @test haskey(settings, "metricsChecks")
        @test haskey(settings, "exposedObjects")

        @test length(settings["settings"]) == 17
        @test set_settings(project, settings) == ""
    end

    @testset "API" begin
        metadata = get_metadata(project)

        @test length(metadata) == 4
        metadata["tags"] = ["test_tag1", "test_tag2"]
        @test set_metadata(project, metadata) == ""

        tags = get_tags(project)
        @test length(tags["tags"]) == 2
        @test set_tags(project, tags) == ""

        variables = get_variables(project)
        @test length(variables) == 2
        @test set_variables(project, variables) == ""

        permissions = get_permissions(project)
        @test length(permissions) == 4
        @test set_permissions(project, permissions) == ""
    end

    io = export_project(project)
    @test length(read(io)) > 3000

    new_project = duplicate(project, "new_"*projectName, "NEW_"*projectKey)
    @test length(list_projects()) > 1
    @test delete(new_project) == ""
end