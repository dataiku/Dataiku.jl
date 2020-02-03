
@testset "Datasets" begin

    @testset "API" begin

        @testset "Schema" begin
            schema = Dataiku.get_schema(dataset)
            columns = schema["columns"]
            @test length(Dataiku.get_column_names(columns)) == 18

            @test columns[1] == Dict("name" => "id", "type" => "bigint")
            @test columns[2] == Dict("name" => "Date", "type" => "string")
            @test columns[3] == Dict("name" => "Date_parsed", "type" => "date")
            @test columns[4] == Dict("name" => "holiday_bank", "type" => "boolean")
            @test columns[end] == Dict("name" => "nb_colis", "type" => "double")

            schema["userModified"] = false
        end

        @testset "Settings" begin
            settings = Dataiku.get_settings(dataset)

            @test length(settings) == 19
            @test dataset.project.key == projectKey
            @test settings["formatType"] == "csv"
            @test settings["schema"] == Dataiku.get_schema(dataset)

            @test Dataiku.set_settings(dataset, settings)["msg"] == "Updated dataset $projectKey.$datasetName"
        end

        @testset "Metadata" begin
            metadata = Dataiku.get_metadata(dataset)

            @test length(metadata) == 3
            @test haskey(metadata, "checklists")
            @test haskey(metadata, "tags")
            @test haskey(metadata, "custom")

            @test Dataiku.set_metadata(dataset, metadata)["msg"] == "updated metadata for $projectKey.$datasetName"
        end

        @test Dataiku.list_partitions(dataset)[1] == "NP"
    end

    @testset "DataFrame" begin
        df = Dataiku.get_dataframe(dataset)

        @testset "Dimensions" begin
            @test nrow(df) == 800
            @test ncol(df) == 18
        end

        @testset "Column Names" begin
            @test names(df)[1] == Symbol("id")
            @test names(df)[end] == Symbol("nb_colis")
        end

        @testset "Column Types" begin
            @test eltype(df[!, 1]) <: Union{Missing, Int64}
            @test eltype(df[!, 3]) <: Union{Missing, DateTime}
            @test eltype(df[!, 4]) <: Union{Missing, Bool}
            @test eltype(df[!, 16]) <: Union{Missing, String}
            @test eltype(df[!, end]) <: Union{Missing, Float64}
        end

        @testset "Values" begin
            @test df[1, 1] == 1
            @test df[1, 3] == DateTime(2014, 06, 18, 0)
            @test df[1, 4] == false
            @test df[1, 16] == "Bordeaux"
            @test df[1, end] == 0.

            @test df[end, 1] == 999
            @test df[end, 3] == DateTime(2014, 07, 29, 0)
            @test df[end, 4] == false
            @test df[end, 16] == "Lyon"
            @test df[end, end] == 88.

            @test df[10, 5] == """["Noël"]"""
            @test df[4, 7] == """["Vacances de printemps - Zone B","Vacances de printemps - Zone C"]"""
            @test df[4, 6] == true
        end
    end
end
