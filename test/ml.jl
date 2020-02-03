@testset "ml" begin
    analysis = Dataiku.create_analysis(dataset)

    mltask = Dataiku.create_prediction_ml_task(dataset, :nb_colis)
    Dataiku.create_prediction_ml_task(analysis, :nb_colis)

    Dataiku.create_clustering_ml_task(dataset)
    Dataiku.create_clustering_ml_task(analysis)

    @test Dataiku.get_status(mltask)["guessing"] == false
    @test Dataiku.guess(mltask)["predictionType"] == "REGRESSION"

    @test Dataiku.list_analysis() |> length == 3
    @test Dataiku.list_ml_tasks(analysis) |> length == 2
    @test Dataiku.list_ml_tasks() |> length == 4

    ids = Dataiku.train(mltask)
    @test length(ids) == 2

    ensemble = Dataiku.ensemble(mltask, ids, "AVERAGE")
    user_meta = Dataiku.get_user_meta(ensemble)
    @test user_meta["name"] == "Ensemble"

    user_meta["description"] = "test_description"

    Dataiku.set_user_meta(ensemble, user_meta)
    @test Dataiku.get_user_meta(ensemble)["description"] == "test_description"

    settings = Dataiku.get_settings(mltask)
    @test settings["targetVariable"] == "nb_colis"
    @test Dataiku.guess(mltask)["targetVariable"] == "nb_colis"
    @test Dataiku.get_status(mltask)["guessing"] == false

    settings["modeling"]["neural_network"]["enabled"] = true
    Dataiku.set_settings(mltask, settings)
    trained_model_id = Dataiku.train(mltask)

    @test length(trained_model_id) == 3

    trained_model = DSSTrainedModel(mltask, "s1", "RANDOM_FOREST_REGRESSION")

    @test Dataiku.get_snippet(trained_model)["algorithm"] == "RANDOM_FOREST_REGRESSION"
    
    saved_model = Dataiku.deploy_to_flow(trained_model)
    @test Dataiku.redeploy_to_flow(trained_model, saved_model) == Dict("impactsDownstream" => false)

    versions = Dataiku.list_versions(saved_model)
    @test length(versions) == 2

    version = DSSModelVersion(saved_model, versions[versions[1]["active"] ? 2 : 1])
    @test Dataiku.set_active(version) == Dict("schemaChanged" => false)

    version_user_meta = Dataiku.get_user_meta(version)
    version_user_meta["description"] = "test description"
    Dataiku.set_user_meta(version, version_user_meta)

    @test Dataiku.get_user_meta(version)["description"] == "test description"

    Dataiku.delete(saved_model)
    Dataiku.delete(mltask)
    Dataiku.delete(analysis)
end