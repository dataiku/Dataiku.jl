list_ml_tasks(projectKey::String=get_projectKey()) = request("GET", "projects/$(projectKey)/models/lab/")["mlTasks"]

function get_ml_tasks(mlTaskName::String, projectKey::String=get_projectKey())
    if mlTaskName in [task["mlTaskName"] for task in list_ml_tasks(projectKey)]
        return task
    else
        throw(ArgumentError("mlTask \"$(mlTaskName)\" doesn't exist"))
    end
end

function get_the_settings_of_a_ml_task(analysisId::String, mlTaskId::String, projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/settings")
end

function get_the_settings_of_a_ml_task(mlTask::Dict, projectKey::String=get_projectKey())
    get_the_settings_of_a_ml_task(mlTask["analysisId"], mlTask["mlTaskId"], projectKey)
end

function get_the_status_of_a_ml_task(analysisId::String, mlTaskId::String, projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/status")
end

function get_the_status_of_a_ml_task(mlTask::Dict, projectKey::String=get_projectKey())
    get_the_status_of_a_ml_task(mlTask["analysisId"], mlTask["mlTaskId"], projectKey)
end


# Ticket id : 35120

# function get_the_snippets_of_a_set_of_trained_models(analysisId::String, mlTaskId::String, projectKey::String=get_projectKey())
# 	request("GET", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/models-snippets")
# end

function get_the_details_of_a_trained_model(analysisId::String, mlTaskId::String, modelFullId::String, projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/models/$(modelFullId)/details")
end

function get_the_details_of_a_trained_model(mlTask::Dict, modelFullId::String, projectKey::String=get_projectKey())
    get_the_details_of_a_trained_model(mlTask["analysisId"], mlTask["mlTaskId"], modelFullId, projectKey)
end



function list_saved_models(projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/savedmodels/")
end

function list_versions(savedModelId::String, projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/savedmodels/$(savedModelId)/versions")
end

function get_snippet_of_a_version(savedModelId::String, versionId::String, projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/savedmodels/$(savedModelId)/versions/$(versionId)/snippet")
end

function get_details_of_a_version(savedModelId::String, versionId::String, projectKey::String=get_projectKey())
    request("GET", "projects/$(projectKey)/savedmodels/$(savedModelId)/versions/$(versionId)/details")
end


function create_a_ml_task(body::Dict, projectKey::String=get_projectKey())
    request("POST", "projects/$(projectKey)/models/lab/", body)
end

function start_training_a_ml_task(analysisId::String,
                                  mlTaskId::String,
                                  projectKey::String=get_projectKey();
                                  sessionName::Union{Nothing, String}=nothing,
                                  sessionDescription::Union{Nothing, String}=nothing)
    body = Dict()
    if sessionName != nothing body["sessionName"] = sessionName end
    if sessionDescription != nothing body["sessionDescription"] = sessionDescription end
    request("POST", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/train", body)
end

function start_training_a_ml_task(mlTask::Dict, projectKey::String=get_projectKey();
                                    sessionName::Union{Nothing, String}=nothing,
                                    sessionDescription::Union{Nothing, String}=nothing)
    start_training_a_ml_task(mlTask["analysisId"], mlTask["mlTaskId"], projectKey, sessionName, sessionDescription)
end

function deploy_a_trained_model_to_flow(body::Dict, analysisId::String,
                                                    mlTaskId::String,
                                                    modelFullId::String, 
                                                    projectKey::String=get_projectKey())
    request("POST", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/models/$(modelFullId)/actions/deployToFlow", body)
end

function deploy_a_trained_model_to_flow(body::Dict, mlTask::Dict, modelFullId::String, projectKey::String=get_projectKey())
    deploy_a_trained_model_to_flow(body, mlTask["analysisId"], mlTask["mlTaskId"], modelFullId, projectKey)
end

function set_a_version_as_active(savedModelId::String,
                                    versionId::String,
                                    projectKey::String=get_projectKey())
    request("POST", "projects/$(projectKey)/savedmodels/$(savedModelId)/versions/$(versionId)/actions/setActive")
end

function saves_user_metadata_for_a_trained_model(userMeta::Dict, analysisId::String,
                                                                 mlTaskId::String,
                                                                 modelFullId::String,
                                                                 projectKey::String=get_projectKey())
    request("PUT", "projects/$(projectKey)/models/lab/$(analysisId)/$(mlTaskId)/models/$(modelFullId)/user-meta", userMeta)
end

function saves_user_metadata_for_a_trained_model(userMeta::Dict, mlTask::Dict, modelFullId::String, projectKey::String=get_projectKey())
    saves_user_metadata_for_a_trained_model(userMeta, mlTask["analysisId"], mlTask["mlTaskId"], modelFullId, projectKey)
end

function set_a_version_user_meta(userMeta::Dict, savedModelId::String, versionId::String, projectKey::String=get_projectKey())
    request("PUT", "projects/$(projectKey)/savedmodels/$(savedModelId)/versions/$(versionId)/user-meta", userMeta)
end


function list_tasks_in_progress(allUsers::Bool=false, withScenarios::Bool= false)
    request("GET", "futures/?allUsers=$(allUsers)&withScenarios=$(withScenarios)")
end

get_status_of_a_running_task(jobId::String, peek::Bool=false) = request("GET", "futures/$(jobId)?peek=$(peek)")

abort_a_task(jobId::String) = request("GET", "futures/$(jobId)")