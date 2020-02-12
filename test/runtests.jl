using Dataiku
using Test
using CSV
using DataFrames
using Dates

try Dataiku.delete(project"TEST_PROJECT") catch end
project = Dataiku.create_project("test_project")

Dataiku.set_current_project(project)


test_dir = joinpath(dirname(dirname(pathof(Dataiku))), "test")

body = Dict(
    "projectKey"   => project.key,
    "type"         => "Filesystem",
    "formatType"   => "csv",
    "managed"      => false,
    "params"       => Dict("connection" => "filesystem_root"),
    "formatParams" => Dict("style" => "excel", "separator"  => ",", "parseHeaderRow" => true),
    "schema"       => Dict{String, Any}("userModified" => true)
)

function test_dataframe_values(exp_df, df)
    @test size(exp_df, 1) == size(df, 1)
    for i in min(size(exp_df, 1),size(df, 1))
        @test size(exp_df, 2) == size(df, 2)
        for j in min(size(exp_df, 2),size(df, 2))
            if ismissing(exp_df[i, j])
                @test ismissing(df[i, j])
            else
                @test exp_df[i, j] == df[i, j]
            end
        end
    end
end

function test_schema(expected, schema)
    columns = schema["columns"]

    @test length(columns) == length(expected)
    for i in 1:min(length(columns), length(expected))
        @test columns[i] == expected[i]
    end
end

@testset "Not Partitionned" begin

    np_body = deepcopy(body)

    schema_no_part = [
        Dict("name" => "c_float", "type" => "float"),
        Dict("name" => "c_bigint", "type" => "bigint"),
        Dict("name" => "c_string", "type" => "string"),
        Dict("name" => "c_boolean", "type" => "boolean"),
        Dict("name" => "c_date", "type" => "date"),
    ]

    np_body["name"] = "dataset_no_part"
    np_body["params"]["path"] = joinpath(test_dir, "data", "no_part.csv")
    np_body["schema"]["columns"] = schema_no_part

    ds_no_part = Dataiku.create_dataset(np_body)
    
    @testset "Schema" begin
        test_schema(schema_no_part, Dataiku.get_schema(ds_no_part))
    end

    data = Dataiku.get_dataframe(ds_no_part)

    exp_df = CSV.File(joinpath(test_dir,"data", "no_part.csv"); header=true, dateformat=Dataiku.DKU_DATE_FORMAT) |> DataFrame!

    @testset "reading" begin

        @testset "Single request" begin
            test_dataframe_values(exp_df, data)
            test_dataframe_values(exp_df[1:2, :], Dataiku.get_dataframe(ds_no_part; limit=2))
        end
        
        @testset "Data Streaming" begin
            chnl = Dataiku.iter_data_chunks(ds_no_part)
            data =  take!(chnl)
            test_dataframe_values(exp_df, data)
            try take!(chnl)
            catch
                @test !isopen(chnl)
            end

            chnl = Dataiku.iter_dataframes(ds_no_part, 1)
            for i in 1:3
                test_dataframe_values(exp_df[i:i, :], take!(chnl))
            end
        end
    end

    @testset "writing" begin
        writing_dataset = Dataiku.create_dataset("writing_no_part_dataset")
        Dataiku.write_with_schema(writing_dataset, data)
        test_dataframe_values(exp_df, Dataiku.get_dataframe(writing_dataset))

        Dataiku.delete(writing_dataset)
    end

    Dataiku.delete(ds_no_part)
end


@testset "Partitionned" begin

    p_body = deepcopy(body)

    schema_part = [
        Dict("name" => "A", "type" => "bigint"),
        Dict("name" => "B", "type" => "bigint"),
        Dict("name" => "C", "type" => "bigint")
    ]

    p_body["name"] = "dataset_part"
    p_body["params"]["path"] = joinpath(test_dir, "data", "part")
    p_body["schema"]["columns"] = schema_part
    p_body["partitioning"] =  Dict(
        "filePathPattern" => "%{A}/.*",
        "dimensions" => [Dict("name" => "A", "type" => "value")]
    )

    ds_part = Dataiku.create_dataset(p_body)

    @testset "Schema" begin
        test_schema(schema_part, Dataiku.get_schema(ds_part))
    end

    dir = joinpath(test_dir,"data", "part")

    @testset "reading" begin
        for part in "ABC"
            exp_data = CSV.File(joinpath(dir, string(part), "test.csv"); header=true) |> DataFrame!
            data = Dataiku.get_dataframe(ds_part; partitions=[part])
            test_dataframe_values(exp_data, data)
        end

        data = Dataiku.get_dataframe(ds_part, [:A]; partitions=[:A])
        test_dataframe_values(DataFrame!([[1, 4]]), data)
    end

    @testset "writting" begin
        p_body["name"] = "writing_part_dataset"
        p_body["params"] = Dict(
            "connection" => "filesystem_managed",
            "path"       => project.key * "/" * p_body["name"]
        )
        p_body["managed"] = true
    
        exp_df = CSV.File(joinpath(test_dir, "data", "no_part.csv"); header=true) |> DataFrame!
        writing_dataset = Dataiku.create_dataset(p_body)
        Dataiku.write_with_schema(writing_dataset, exp_df; partition=:A)
        test_dataframe_values(exp_df, Dataiku.get_dataframe(writing_dataset; partitions=[:A]))

        Dataiku.delete(writing_dataset)
    end

    Dataiku.delete(ds_part)

end

Dataiku.delete(project)