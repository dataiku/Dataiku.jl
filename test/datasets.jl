
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
        df = Dataiku.get_dataframe(dataset; infer_types=false)

        @testset "Dimensions" begin
            @test nrow(df) == 800
            @test ncol(df) == 18
        end

        @testset "Column Names" begin
            @test names(df)[1] == Symbol("id")
            @test names(df)[end] == Symbol("nb_colis")
        end

        @testset "Column Types" begin
            @test eltypes(df)[1] <: Union{Missing, Int64}
            @test eltypes(df)[2] <: Union{Missing, String}
            @test eltypes(df)[3] <: Union{Missing, DateTime}
            @test eltypes(df)[4] <: Union{Missing, Bool}
            @test eltypes(df)[end] <: Union{Missing, Float64}
        end

        @testset "Values" begin
            @test df[1][1] == 1
            @test df[2][1] == "2014-06-18"
            @test df[3][1] == DateTime("2014-06-18T00:00:00.000Z", "yyyy-mm-ddTHH:MM:SS.sssZ")
            @test df[4][1] == false
            @test df[end][1] == 0.

            @test df[1][end] == 999
            @test df[2][end] == "2014-07-29"
            @test df[3][end] == DateTime("2014-07-29T00:00:00.000Z", "yyyy-mm-ddTHH:MM:SS.sssZ")
            @test df[4][end] == false
            @test df[end][end] == 88.

            @test df[5][10] == """["Noël"]"""
            @test df[7][4] == """["Vacances de printemps - Zone B","Vacances de printemps - Zone C"]"""
            @test df[6][4] == true
        end
    end

    @testset "Iteration" begin
        chnl = Dataiku.iter_rows(dataset; infer_types=false)
        row = take!(chnl)
        @testset "Row Values" begin
            @test row[1] == 1
            @test row[2] == "2014-06-18"
            @test row[3] == DateTime("2014-06-18T00:00:00.000Z", "yyyy-mm-ddTHH:MM:SS.sssZ")
            @test row[4] == false
            @test row[end] == 0.
        end

        chnl = Dataiku.iter_tuples(dataset; infer_types=false)
        tuple = take!(chnl)
        @testset "Tuples Values" begin
            @test tuple[1] == 1
            @test tuple[2] == "2014-06-18"
            @test tuple[3] == DateTime("2014-06-18T00:00:00.000Z", "yyyy-mm-ddTHH:MM:SS.sssZ")
            @test tuple[4] == false
            @test tuple[end] == 0.
        end

        @testset "Streaming data" begin
            Dataiku.write_dataframe(dataset) do chnl
                for chunk in Dataiku.iter_dataframes(dataset, 100)
                    put!(chnl, chunk)
                end
            end
            df = Dataiku.get_dataframe(dataset; infer_types=false)

            @test df[1][1] == 1
            @test df[2][1] == "2014-06-18"
            @test df[3][1] == DateTime("2014-06-18T00:00:00.000Z", "yyyy-mm-ddTHH:MM:SS.sssZ")
            @test df[4][1] == false
            @test df[end][1] == 0.

            @test df[1][end] == 999
            @test df[2][end] == "2014-07-29"
            @test df[3][end] == DateTime("2014-07-29T00:00:00.000Z", "yyyy-mm-ddTHH:MM:SS.sssZ")
            @test df[4][end] == false
            @test df[end][end] == 88.

            @test df[5][10] == """["Noël"]"""
            @test df[7][4] == """["Vacances de printemps - Zone B","Vacances de printemps - Zone C"]"""
            @test df[6][4] == true
        end
    end
end
