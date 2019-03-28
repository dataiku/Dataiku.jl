const scenarioName = "test_scenario"

@testset "Scenarios" begin

    scenario = create_scenario(scenarioName, "step_based", Dict{Any}("params" =>Dict()))
end