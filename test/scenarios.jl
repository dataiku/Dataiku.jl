const scenarioName = "test_scenario"

@testset "Scenarios" begin
    scenario = Dataiku.create_scenario(scenarioName, "custom_python")
    @test length(Dataiku.list_scenarios()) == 1

    @testset "settings" begin
        status = Dataiku.get_status(scenario)
        @test status["name"] == scenarioName
        status["active"] = true
        @test Dataiku.set_status(scenario, status)["msg"] == "Updated scenario $projectKey.$scenarioName"

        settings = Dataiku.get_settings(scenario)
        @test settings["active"]
        @test settings["customFields"] == Dict()
        settings["tags"] = ["test"]
        @test Dataiku.set_settings(scenario, settings)["msg"] == "Updated scenario $projectKey.$scenarioName"
        @test Dataiku.get_settings(scenario)["tags"][1] == "test"
    end

    @testset "execution" begin
        payload = "import time; time.sleep(1)"
        Dataiku.set_payload(scenario, payload)
        @test Dataiku.get_payload(scenario) == "import time; time.sleep(1)"

        triggerfire = Dataiku.run_and_wait(scenario)
        run = Dataiku.get_scenario_run(triggerfire)
        @test Dataiku.get_details(run)["stepRuns"] == []

        Dataiku.run(scenario)
        @test Dataiku.get_current_run(scenario)["end"] == 0

        Dataiku.run(scenario)
        @test Dataiku.abort(scenario)["msg"] == "abort requested"
    end
end