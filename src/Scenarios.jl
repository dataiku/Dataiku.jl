struct DSSScenario <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSScenario(id::AbstractString, project::DSSProject=get_current_project()) = new(project, id)
end

macro scenario_str(str)
    createobject(DSSScenario, str)
end

export @scenario_str
export DSSScenario

list_scenarios(project::DSSProject=get_current_project()) = request("GET", "projects/$(project.key)/scenarios/")

get_settings(scenario::DSSScenario, with_status=true) =
    request("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)" * (with_status ? "" : "/light"))

set_settings(scenario::DSSScenario, settings::AbstractDict) =
    request("PUT", "projects/$(scenario.project.key)/scenarios/$(scenario.id)", settings)


get_status(scenario::DSSScenario) =
    request("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/light")

set_status(scenario::DSSScenario, status::AbstractDict) =
    request("PUT", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/light", status)


get_payload(scenario::DSSScenario) =
    request("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/payload")["script"] ## Error when no payload

set_payload(scenario::DSSScenario, script::AbstractString) =
    request("PUT", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/payload", Dict("script" => script))


list_last_runs(scenario::DSSScenario, limit::Integer=10) =
    request("GET", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/get-last-runs/?limit=$(limit)")


"""
`create_scenario(scenario_name::AbstractString, scenario_type::AbstractString, definition::AbstractDict`

Create a new scenario in the project, and return a handle to interact with it
* `scenario_name::AbstractString` The name for the new scenario. This does not need to be unique (although this is strongly recommended)
* `scenario_type::AbstractString` The type of the scenario. MUst be one of `step_based` or `custom_python`
* `definition::AbstractDict` the JSON definition of the scenario. Use `get_settings` on an existing `DSSScenario` object in order to get a sample definition object
returns: a `DSSScenario` handle to interact with the newly-created scenario
"""
function create_scenario(scenario_name, scenario_type, definition::AbstractDict, project::DSSProject=get_current_project())
    definition["name"] = scenario_name
    definition["type"] = scenario_type # step_based or custom_python
    scenario_id = request("POST", "projects/$(project.key)/scenarios/", definition)["id"]
    DSSScenario(scenario_id, project)
end

struct DSSRun
    scenario::DSSScenario
    id::AbstractString
    triggerId::AbstractString
end

export DSSRun

function run_scenario(scenario::DSSScenario, body::AbstractDict=Dict()) # you can send trigger parameters, not required
    res = request("POST", "projects/$(scenario.project.key)/scenarios/$(scenario.id)/run", body)
    DSSRun(scenario, res["runId"], "manual")
end

get_details(run::DSSRun) = request("GET", "projects/$(run.scenario.project.key)/scenarios/$(run.scenario.id)/$(run.id)/")

abort_scenario(scenario::DSSScenario) = request("POST", "projects/$(run.scenario.project.key)/scenarios/$(run.scenario.id)/abort")

function get_settings(run::DSSRun) 
    params = Dict("triggerRunId" => run.id,
                  "triggerId"    => run.triggerId)
    request("GET", "projects/$(run.scenario.project.key)/scenarios/$(run.scenario.id)/get-run-for-trigger/"; params=params)["scenarioRun"]
end

# same than the ["trigger"] field of get_settings, not really useful

# function get_a_run_of_a_trigger(run::DSSRun)
#     request("GET", "projects/$(run.project.key)/scenarios/trigger/$(run.scenarioId)/$(run.triggerId)?triggerRunId=$(run.id)")
# end

export get_status
export set_status
export get_payload
export set_payload
export create_scenario