struct DSSAnalysis <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSAnalysis(id, project::DSSProject=get_current_project()) = new(project, id)
end
export DSSAnalysis

function create_analysis(dataset::DSSDataset)
    res = request_json("POST", "projects/$(dataset.project.key)/lab/", Dict("inputDataset" => dataset.name))
    DSSAnalysis(res["id"], dataset.project)
end

list_analysis(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/lab/")

delete(analysis::DSSAnalysis) = delete_request("projects/$(analysis.project.key)/lab/$(analysis.id)/")

struct DSSMLTask <: DSSObject
    analysis::DSSAnalysis
    id::AbstractString
    DSSMLTask(analysisId, mlTaskId, project::DSSProject=get_current_project()) = new(DSSAnalysis(analysisId, project), mlTaskId)
    DSSMLTask(name::AbstractString, project::DSSProject=get_current_project()) = DSSMLTask(find_field(list_ml_tasks(), "mlTaskName", name), project)
    DSSMLTask(dict::AbstractDict, project::DSSProject=get_current_project()) = DSSMLTask(dict["analysisId"], dict["mlTaskId"], project)
end
export DSSMLTask

list_ml_tasks(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/models/lab/")["mlTasks"]
list_ml_tasks(analysis::DSSAnalysis) = request_json("GET", "projects/$(analysis.project.key)/lab/$(analysis.id)/models/")["mlTasks"]

"""
```julia
create_prediction_ml_task(dataset::DSSDataset, targetVariable; backendType="PY_MEMORY", guessPolicy="DEFAULT", prediction_type=nothing, wait_guess=true)
```
Creates a new prediction task in a new visual analysis lab for a dataset.
#### Params
* `ml_backend_type="PY_MEMORY`  ML backend to use, one of PY_MEMORY, MLLIB or H2O
* `guess_policy="DEFAULT"` Policy to use for setting the default parameters. Valid values are: `DEFAULT`, `SIMPLE_FORMULA`, `DECISION_TREE`, `EXPLANATORY` and `PERFORMANCE`
* `prediction_type` The type of prediction problem this is. If not provided the prediction type will be guessed. Valid values are: `BINARY_CLASSIFICATION`, `REGRESSION`, `MULTICLASS`
* `wait_guess_complete=true` if false, the returned ML task will be in 'guessing' state, i.e. analyzing the input dataset to determine feature handling and algorithms.
Returns a DSSMLTask
"""
function create_prediction_ml_task(dataset::DSSDataset, targetVariable; backendType="PY_MEMORY", guessPolicy="DEFAULT", prediction_type=nothing, wait_guess=true)
    body = Dict(
        "taskType" => "PREDICTION",
        "inputDataset" => dataset.name,
        "targetVariable" => targetVariable,
        "backendType" => backendType,
        "guessPolicy" => guessPolicy,
        "prediction_type" => prediction_type
    )
    create_ml_task(dataset, body; wait_guess=wait_guess)
end


"""
```julia
create_clustering_ml_task(dataset::DSSDataset; backendType="PY_MEMORY", guessPolicy="KMEANS", wait_guess=true)
```
Creates a new prediction task in an existing analysis
#### Params
* `ml_backend_type="PY_MEMORY"` ML backend to use, one of `PY_MEMORY`, `MLLIB` or `H2O`
* `guess_policy="KMEANS"` Policy to use for setting the default parameters.  Valid values are: `KMEANS` and `ANOMALY_DETECTION`
* `wait_guess_complete=true` if false, the returned ML task will be in 'guessing' state, i.e. analyzing the input dataset to determine feature handling and algorithms.
Returns a DSSMLTask
"""
function create_clustering_ml_task(dataset::DSSDataset; backendType="PY_MEMORY", guessPolicy="KMEANS", wait_guess=true)
    body = Dict(
        "taskType" => "CLUSTERING",
        "inputDataset" => dataset.name,
        "backendType" => backendType,
        "guessPolicy" => guessPolicy
    )
    create_ml_task(dataset, body; wait_guess=wait_guess)
end

function create_ml_task(dataset::DSSDataset, body::AbstractDict; wait_guess=true)
    res = request_json("POST", "projects/$(dataset.project.key)/models/lab/", body)
    mltask = DSSMLTask(res, dataset.project)
    wait_guess && wait_guess_complete(mltask)
    mltask
end


"""
```julia
create_prediction_ml_task(analysis::DSSAnalysis, targetVariable; backendType="PY_MEMORY", guessPolicy="DEFAULT", prediction_type=nothing, wait_guess=true)
```
Creates a new prediction task in an existing analysis
#### Params
* `ml_backend_type="PY_MEMORY`  ML backend to use, one of PY_MEMORY, MLLIB or H2O
* `guess_policy="DEFAULT"` Policy to use for setting the default parameters. Valid values are: `DEFAULT`, `SIMPLE_FORMULA`, `DECISION_TREE`, `EXPLANATORY` and `PERFORMANCE`
* `prediction_type` The type of prediction problem this is. If not provided the prediction type will be guessed. Valid values are: `BINARY_CLASSIFICATION`, `REGRESSION`, `MULTICLASS`
* `wait_guess_complete=true` if false, the returned ML task will be in 'guessing' state, i.e. analyzing the input dataset to determine feature handling and algorithms.
Returns a DSSMLTask
"""
function create_prediction_ml_task(analysis::DSSAnalysis, targetVariable;
        backendType="PY_MEMORY", guessPolicy="DEFAULT", prediction_type=nothing, wait_guess=true)
    body = Dict(
        "taskType" => "PREDICTION",
        "targetVariable" => targetVariable,
        "backendType" => backendType,
        "guessPolicy" => guessPolicy,
        "prediction_type" => prediction_type
    )
    create_ml_task(analysis, body; wait_guess=wait_guess)
end

"""
```julia
create_clustering_ml_task(analysis::DSSAnalysis; backendType="PY_MEMORY", guessPolicy="KMEANS" wait_guess=true)
```
Creates a new clustering task in an existing analysis.
#### Params
* `ml_backend_type="PY_MEMORY"` ML backend to use, one of `PY_MEMORY`, `MLLIB` or `H2O`
* `guess_policy="KMEANS"` Policy to use for setting the default parameters.  Valid values are: `KMEANS` and `ANOMALY_DETECTION`
* `wait_guess_complete=true` if false, the returned ML task will be in 'guessing' state, i.e. analyzing the input dataset to determine feature handling and algorithms.
Returns a DSSMLTask
"""
function create_clustering_ml_task(analysis::DSSAnalysis; backendType="PY_MEMORY", guessPolicy="KMEANS", wait_guess=true)
    body = Dict(
        "taskType" => "CLUSTERING",
        "backendType" => backendType,
        "guessPolicy" => guessPolicy,
    )
    create_ml_task(analysis, body; wait_guess=wait_guess)
end

function create_ml_task(analysis::DSSAnalysis, body::AbstractDict; wait_guess=true)
    res = request_json("POST", "projects/$(analysis.project.key)/lab/$(analysis.id)/models/", body)
    mltask = DSSMLTask(res, analysis.project)
    wait_guess && wait_guess_complete(mltask)
    mltask
end


get_settings(mltask::DSSMLTask) = request_json("GET", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/settings")
set_settings(mltask::DSSMLTask, body) = request_json("POST", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/settings", body)

get_status(mltask::DSSMLTask) = request_json("GET", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/status")

"""
```julia
train(mltask::DSSMLTask; params...)
```
Trains models for this ML Task
#### Params
* `session_name` name for the session
* `session_description` description for the session

This method waits for train to complete. If you want to train asynchronously, use `start_train` and `wait_train_complete`
This method returns the list of trained model identifiers. It returns models that have been trained  for this train
session, not all trained models for this ML task. To get all identifiers for all models trained across all training sessions,
use `get_trained_models_ids`
These identifiers can be used for `get_trained_model_snippet`, `get_trained_model_details` and `deploy_to_flow`
"""
function train(mltask::DSSMLTask; body...)
    res = start_train(mltask; body...)
    wait_train_complete(mltask)
    get_trained_models_ids(mltask, res["sessionId"])
end

"""
```julia
ensemble(mltask::DSSMLTask, method, model_ids=[])
```
Create an ensemble model of a set of models
#### Params
* `model_ids` A list of model identifiers
* `method` the ensembling method. One of: `AVERAGE`, `PROBA_AVERAGE`, `MEDIAN`, `VOTE`, `LINEAR_MODEL`, `LOGISTIC_MODEL`
This method waits for the ensemble train to complete. If you want to train asynchronously, use `start_ensembling` and `wait_train_complete`

To get all identifiers for all models trained across all training sessions, use `get_trained_models_ids`
This identifier can be used for `get_trained_model_snippet`, `get_trained_model_details` and `deploy_to_flow`
returns a DSSTrainedModel
"""
function ensemble(mltask::DSSMLTask, model_ids::AbstractArray=[], method::AbstractString="")
    res = start_ensembling(mltask, model_ids, method)
    wait_train_complete(mltask)
    DSSTrainedModel(res["id"])
end

start_train(mltask::DSSMLTask; body...) =
    request_json("POST", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/train", body)

function start_ensembling(mltask::DSSMLTask, model_ids::AbstractArray=[], method::AbstractString="")
    body = Dict(
        "method" => method,
        "modelsIds" => model_ids
    )
    request_json("POST", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/ensemble", body)
end

function wait_train_complete(mltask::DSSMLTask)
    while get_status(mltask)["training"]
        sleep(2)
    end
end

"""
```julia
guess(mltask::DSSMLTask, prediction_type=nothing)
```
Guess the feature handling and the algorithms.
In case of a prediction problem the prediction type can be specify.
Valid values are "BINARY_CLASSIFICATION", "REGRESSION", "MULTICLASS".
"""
guess(mltask::DSSMLTask, prediction_type=nothing) =
    request_json("PUT", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/guess", Dict("predictionType" => prediction_type))

function wait_guess_complete(mltask::DSSMLTask)
    while get_status(mltask)["guessing"]
        sleep(0.2)
    end
end

delete(mltask::DSSMLTask) = delete_request("projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/")

"""
```julia
struct DSSTrainedModel <: DSSObject
    mltask::DSSMLTask
    fullId::AbstractString
end

DSSTrainedModel(modelFullId::AbstractString)
DSSTrainedModel(mltask::DSSMLTask, sessionId, algorithm)
```
algorithms:
`LARS`                    
`RANDOM_FOREST_REGRESSION`
`RIDGE_REGRESSION`        
`KNN`                     
`NEURAL_NETWORK`          
`LEASTSQUARE_REGRESSION`  
`EXTRA_TREES`             
`SGD_REGRESSION`          
`XGBOOST_REGRESSION`      
`DECISION_TREE_REGRESSION`
`SVM_REGRESSION`          
`GBT_REGRESSION`          
`LASSO_REGRESSION`
`KMEANS`(clustering)

`get_trained_models_ids(mltask::DSSMLTask[, sessionId, algorithm])` to list all the trained models of the mltask
"""
struct DSSTrainedModel <: DSSObject
    mltask::DSSMLTask
    fullId::AbstractString

    function DSSTrainedModel(modelFullId::AbstractString)
        s = split(modelFullId, '-')
        if length(s) != 7
            throw(ArgumentError("invalid modelFullId"))
        end
        new(DSSMLTask(s[3], s[4], DSSProject(s[2])), modelFullId)
    end

    function DSSTrainedModel(mltask::DSSMLTask, sessionId=nothing, algorithm=nothing)
        fullId = get_trained_models_ids(mltask, sessionId, algorithm)
        if length(fullId) > 1
            throw(DkuException("More than one trained model matches the parameters"))
        elseif isempty(fullId)
            throw(DkuException("No trained model matches the parameters"))
        end
        new(mltask, first(fullId))
    end
end

macro trainedmodel_str(str)
    DSSTrainedModel(str)
end

export @trainedmodel_str
export DSSTrainedModel

"""
```julia
get_trained_models_ids(mltask::DSSMLTask[, sessionId, algorithm])
```
Gets the list of trained model identifiers for this ML task.
"""
get_trained_models_ids(mltask::DSSMLTask, session::Integer, algorithm=nothing) = get_trained_models_ids(mltask, "s$session", algorithm)

function get_trained_models_ids(mltask::DSSMLTask, session=nothing, algorithm=nothing)
    full_model_ids = get_status(mltask)["fullModelIds"]
    if !isnothing(session)
        full_model_ids = [fmi for fmi in full_model_ids if fmi["fullModelId"]["sessionId"] == session]
    end
    model_ids = [x["id"] for x in full_model_ids]
    if !isnothing(algorithm)
        model_ids = [fmi for (fmi, s) in get_trained_model_snippet(mltask, model_ids) if s["algorithm"] == algorithm]
    end
    model_ids
end

"""
```julia
get_snippet(mltask::DSSMLTask, ids)
```
Gets a quick summary of a trained model.
For complete information, use `get_detail(::DSSTrainedModel)`
"""
get_snippet(model::DSSTrainedModel) = get_trained_model_snippet(model.mltask, model.fullId)
"""
```julia
get_trained_model_snippet(mltask::DSSMLTask, id::AbstractString)
get_trained_model_snippet(mltask::DSSMLTask, ids::AbstractArray)
```
Gets a quick summary of one or many trained model, as a dict.
"""
get_trained_model_snippet(mltask::DSSMLTask, id::AbstractString) = get_trained_model_snippet(mltask, [id])[id]
get_trained_model_snippet(mltask::DSSMLTask, ids::AbstractArray) =
    request_json("GET", "projects/$(mltask.analysis.project.key)/models/lab/$(mltask.analysis.id)/$(mltask.id)/models-snippets", Dict("modelsIds" => ids))


get_details(model::DSSTrainedModel) =
    request_json("GET", "projects/$(model.mltask.analysis.project.key)/models/lab/$(model.mltask.analysis.id)/$(model.mltask.id)/models/$(model.fullId)/details")

"""
Updates the user metadata of a model. Update the “userMeta” field of a previously-retrieved model-details object.
```julia
set_user_meta(model::DSSTrainedModel, userMeta::AbstractDict)
```
"""
set_user_meta(model::DSSTrainedModel, userMeta::AbstractDict) =
    request_json("PUT", "projects/$(model.mltask.analysis.project.key)/models/lab/$(model.mltask.analysis.id)/$(model.mltask.id)/models/$(model.fullId)/user-meta", userMeta)

struct DSSSavedModel <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSSavedModel(id::AbstractString, project::DSSProject=get_current_project()) = new(project, id)
end
macro model_str(str)
    createobject(DSSSavedModel, str)
end

export @model_str
export DSSSavedModel

"""
```julia
deploy_to_flow(model::DSSTrainedModel; params...)
```
#### Params
* `trainDatasetRef` Name of the train dataset to use
* `testDatasetRef` Name of the test dataset to use
* `modelName` Name of the saved model in Flow
* `redoOptimization` default : true

returns a `DSSSavedModel`
"""
function deploy_to_flow(model::DSSTrainedModel; params...)
    body = Dict(params...)
    if !haskey(body, "trainDatasetRef") || !haskey(body, "modelName")
        mltask = find_field(list_ml_tasks(), "mlTaskId", model.mltask.id)
        if !haskey(body, "modelName")
            algo = get_snippet(model)["algorithm"]
            body["modelName"] = "$(algo != "KMEANS" ? "Prediction" : "Clustering") ($algo) on $(mltask["inputDataset"])"
        end
        if !haskey(body, "trainDatasetRef")
            body["trainDatasetRef"] = mltask["inputDataset"]
        end
    end
    res = request_json("POST", "projects/$(model.mltask.analysis.project.key)/models/lab/$(model.mltask.analysis.id)/$(model.mltask.id)/models/$(model.fullId)/actions/deployToFlow", body)
    DSSSavedModel(res["savedModelId"], model.mltask.analysis.project)
end

"""
```julia
redeploy_to_flow(trained_model::DSSTrainedModel, saved_model::savedModelId; activate=true)
```
Redeploys a trained model from this ML Task to a saved model + train recipe in the Flow.
`activate` defines if the new version is activated
"""
function redeploy_to_flow(model::DSSTrainedModel, saved_model::DSSSavedModel, activate=true)
    body = Dict(
        "savedModelId" => saved_model.id,
        "activate" => activate
    )
    request_json("POST", "projects/$(model.mltask.analysis.project.key)/models/lab/$(model.mltask.analysis.id)/$(model.mltask.id)/models/$(model.fullId)/actions/redeployToFlow", body)
end

list_saved_models(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/savedmodels/")

delete(model::DSSSavedModel) = delete_request("projects/$(model.project.key)/savedmodels/$(model.id)")

struct DSSModelVersion <: DSSObject
    model::DSSSavedModel
    id::AbstractString
    DSSModelVersion(model::DSSSavedModel, id::AbstractString) = new(model, id)
    DSSModelVersion(model::DSSSavedModel, dict::AbstractDict) = new(model, dict["id"])
end
export DSSModelVersion


list_versions(model::DSSSavedModel) = request_json("GET", "projects/$(model.project.key)/savedmodels/$(model.id)/versions")

get_snippet(version::DSSModelVersion) =
    request_json("GET", "projects/$(version.model.project.key)/savedmodels/$(version.model.id)/versions/$(version.id)/snippet")

get_details(version::DSSModelVersion) =
    request_json("GET", "projects/$(version.model.project.key)/savedmodels/$(version.model.id)/versions/$(version.id)/details")

set_active(version::DSSModelVersion) =
    request_json("POST", "projects/$(version.model.project.key)/savedmodels/$(version.model.id)/versions/$(version.id)/actions/setActive")

get_user_meta(model::Union{DSSTrainedModel, DSSModelVersion}) = get_snippet(model)["userMeta"]

set_user_meta(version::DSSModelVersion, usermeta) =
    request_json("PUT", "projects/$(version.model.project.key)/savedmodels/$(version.model.id)/versions/$(version.id)/user-meta", usermeta)