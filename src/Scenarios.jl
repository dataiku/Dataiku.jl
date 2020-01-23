using Statistics

struct DSSScenario <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSScenario(id::AbstractString, project::DSSProject=get_current_project()) = new(project, id)
    DSSScenario(def::AbstractDict) = DSSScenario(def["id"], DSSProject(def["projectKey"]))
end

macro scenario_str(str)
    createobject(DSSScenario, str)
end

export @scenario_str
export DSSScenario

list_scenarios(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/scenarios/")

get_settings(scenario::DSSScenario) =
    request_json("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)")

set_settings(scenario::DSSScenario, settings::AbstractDict) =
    request_json("PUT", "projects/$(scenario.project.key)/scenarios/$(scenario.id)", settings)


get_status(scenario::DSSScenario) =
    request_json("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/light")
"""
```julia
set_status(scenario::DSSScenario, status::AbstractDict)
```
This is only useful to change the “active” status of a scenario
"""
set_status(scenario::DSSScenario, status::AbstractDict) =
    request_json("PUT", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/light", status)


get_payload(scenario::DSSScenario) =
    get(request_json("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/payload"), "script", "")

set_payload(scenario::DSSScenario, script::AbstractString) =
    request_json("PUT", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/payload", Dict("script" => script))

function get_trigger_fire(run::DSSScenario, triggerId, triggerRunId)
    res = request_json("GET", "projects/$(scenario.project.key)/scenarios/trigger/$(scenario.id)/$(triggerId)?triggerRunId=$(triggerRunId)")
    DSSTriggerFire(res)
end

function run(scenario::DSSScenario, trigger_params::AbstractDict=Dict())
    res = request_json("POST", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/run", trigger_params)
    DSSTriggerFire(res)
end

function run_and_wait(scenario::DSSScenario, trigger_params::AbstractDict=Dict(); no_fail=false)
    trigger_fire = run(scenario, trigger_params)
    scenario_run = wait_for_scenario_run(trigger_fire; no_fail=no_fail)
    wait(scenario_run; no_fail=no_fail)
    trigger_fire
end

abort(scenario::DSSScenario) = request_json("POST", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/abort")

function get_current_run(scenario::DSSScenario)
    last_run = get_last_runs(scenario, 1)
    if !isempty(last_run) && !haskey(last_run[1], "result")
        last_run[1]
    end
end

function get_last_runs(scenario::DSSScenario, limit::Integer=10, only_finished_runs=false)
    params = Dict(
        "limit" => limit,
        "onlyFinishedRuns" => only_finished_runs
    )
    request_json("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/get-last-runs/"; params=params)
end

get_average_duration(scenario::DSSScenario, limit=3) = mean([get_duration(run).value for run in get_last_runs(scenario, limit, true)])


"""
```julia
create_scenario(id::AbstractString, type::AbstractString[, project::DSSProject]; kwargs...)
create_scenario(definition::AbstractDict[, project::DSSProject])
```

Create a new scenario in the project, and return a `DSSScenario` to interact with it

Use `Dataiku.get_definition` on an already existing `DSSScenario` to get a sample definition object.
Or give only `id`, `type` and give all others optionnal parameters as keywords arguments

#### Required parameters
* `id::AbstractString` The id for the new scenario. This needs to be unique.
* `type::AbstractString` The type of the scenario. Must be one of `step_based` or `custom_python`

"""
function create_scenario(id, type, project::DSSProject=get_current_project(); params=Dict(), name=id, kwargs...)
    definition = Dict(
        "id" => id,
        "type" => type,
        "name" => name,
        "params" => params
    )
    create_scenario(merge(definition, kwargs...), project)
end

function create_scenario(definition::AbstractDict, project::DSSProject=get_current_project())
    scenario_id = request_json("POST", "projects/$(project.key)/scenarios/", definition)["id"]
    DSSScenario(scenario_id, project)
end

struct DSSScenarioRun <: DSSObject
    scenario::DSSScenario
    id::AbstractString
    DSSScenarioRun(scenario::DSSScenario, id::AbstractString) = new(scenario, id)
    DSSScenarioRun(def::AbstractDict) = new(DSSScenario(def["scenario"]["id"], DSSProject(def["scenario"]["projectKey"])), def["runId"])
end

export DSSScenarioRun

get_start_time(run::DSSScenarioRun) = get_start_time(get_details(run)["scenarioRun"])
get_start_time(run::AbstractDict) = unix2datetime(run["start"]/1000)

get_duration(run::DSSScenarioRun) = get_duration(get_details(run)["scenarioRun"])
get_duration(run::AbstractDict) = (run["end"] > 0 ? unix2datetime(run["end"]/1000) : now(UTC)) - get_start_time(run)

get_details(run::DSSScenarioRun) = request_json("GET", "projects/$(run.scenario.project.key)/scenarios/$(run.scenario.id)/$(run.id)/")

function wait(run::DSSScenarioRun; no_fail=false)
    scenario_run = get_details(run)["scenarioRun"]
    while !haskey(scenario_run, "result")
        sleep(5)
        scenario_run = get_details(run)
    end
    outcome = get(scenario_run["result"], "outcome", "UNKNOWN")
    if no_fail || outcome == "SUCCESS"
        scenario_run
    else
        error("Scenario run returned status $outcome")
    end
end

struct DSSTriggerFire <: DSSObject
    scenario::DSSScenario
    id::AbstractString
    runId::AbstractString
    DSSTriggerFire(scenario::DSSScenario, id::AbstractString, triggerId::AbstractString) = new(scenario, id, triggerId)
    DSSTriggerFire(def::AbstractDict) = new(DSSScenario(def["scenarioId"], DSSProject(def["projectKey"])), def["trigger"]["id"], def["runId"])
end

export DSSTriggerFire

function get_scenario_run(trigger::DSSTriggerFire) 
    params = Dict("triggerRunId" => trigger.runId,
                  "triggerId"    => trigger.id)
    res = request_json("GET", "projects/$(trigger.scenario.project.key)/scenarios/$(trigger.scenario.id)/get-run-for-trigger/"; params=params)
    DSSScenarioRun(res["scenarioRun"])
end

is_cancelled(trigger::DSSTriggerFire) =
    request_json("GET", "projects/$(trigger.scenario.project.key)/scenarios/trigger/$(trigger.scenario.id)/$(trigger.id)"; params=Dict(
        "triggerRunId" => trigger.runId))["cancelled"]

function wait_for_scenario_run(trigger::DSSTriggerFire; no_fail=false)
    scenario_run = nothing
    while isnothing(scenario_run)
        if is_cancelled(trigger)
            if no_fail
                return nothing
            else
                error("Scenario run has been cancelled")
            end
        end
        scenario_run = get_scenario_run(trigger)
        sleep(5)
    end
    scenario_run
end