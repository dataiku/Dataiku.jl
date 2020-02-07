
@testset "Datasets" begin

    function check_dataframe_values(exp, df)
        for (key, value) in exp
            col = getproperty(df, key)
            for i in 1:min(length(value), length(col))
                if ismissing(value[i])
                    @test ismissing(col[i])
                else
                    @test value[i] == col[i]
                end
            end
        end
    end

    expected = Dict(
        :c_float => Union{Float64, Missing}[0.0, 42.4, missing],
        :c_bigint => Union{Int, Missing}[0, 1, missing],
        :c_string => Union{String, Missing}["unicØde string", "'quoted' \"string\"", missing],
        :c_boolean => Union{Bool, Missing}[true, false, missing],
        :c_date => Union{DateTime, Missing}[DateTime(1999, 12, 31, 23, 59, 59, 999), DateTime(2000, 1, 1, 0, 0, 0, 0), missing]
    )

    Dataiku.write_with_schema(dataset, DataFrame(expected))

    df = Dataiku.get_dataframe(dataset)

    check_dataframe_values(expected, df)

    @testset "Schema" begin
        schema = Dataiku.get_schema(dataset)
        columns = schema["columns"]

        @test length(columns) == length(expected)
        for i in 1:min(length(expected), length(columns))
            colname = columns[i]["name"] |> Symbol
            @test haskey(expected, colname)
            @test columns[i]["type"] == Dataiku._type_to_string(eltype(expected[colname]))
        end
    end

    # @testset "Iteration" begin
    #     chnl = Dataiku.iter_rows(dataset)
    #     row = take!(chnl)
    #     @testset "Row Values" begin
    #         @test row[1] == 1
    #         @test row[3] == DateTime(2014, 06, 18, 0)
    #         @test row[4] == false
    #         @test row[16] == "Bordeaux"
    #         @test row[end] == 0.
    #     end

    #     chnl = Dataiku.iter_tuples(dataset)
    #     tuple = take!(chnl)
    #     @testset "Tuples Values" begin
    #         @test tuple[1] == 1
    #         @test tuple[3] == DateTime(2014, 06, 18, 0)
    #         @test tuple[4] == false
    #         @test tuple[16] == "Bordeaux"
    #         @test tuple[end] == 0.
    #     end
    # end
end
