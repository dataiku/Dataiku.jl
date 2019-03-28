struct DSSScenario <: DSSObject
    id::AbstractString
    projectKey::AbstractString
    DSSScenario(id::AbstractString, projectKey=get_projectKey()) = new(id, projectKey)
end

macro scenario_str(str)
    createobject(DSSScenario, str)
end

export @scenario_str
export DSSScenario

list_scenarios(projectKey=get_projectKey()) = request("GET", "projects/$(projectKey)/scenarios/")

function get_settings(scenario::DSSScenario, with_status=true)
    request("GET", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)" * (with_status ? "" : "/light"))
end

function set_settings(scenario::DSSScenario, settings::AbstractDict)
    request("PUT", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)", settings)
end


function get_status(scenario::DSSScenario)
    request("GET", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/light")
end

function set_status(scenario::DSSScenario, status::AbstractDict)
    request("PUT", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/light", status)
end


function get_payload(scenario::DSSScenario)
    request("GET", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/payload")["script"] ## Error when no payload
end

function set_payload(scenario::DSSScenario, script::AbstractString)
    request("PUT", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/payload", Dict("script" => script))
end


function list_last_runs(scenario::DSSScenario, limit::Integer=10)
    request("GET", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/get-last-runs/?limit=$(limit)")
end


"""
`create_scenario(scenario_name::AbstractString, scenario_type::AbstractString, definition::AbstractDict`

Create a new scenario in the project, and return a handle to interact with it
* `scenario_name::AbstractString` The name for the new scenario. This does not need to be unique
                        (although this is strongly recommended)
* `scenario_type::AbstractString` The type of the scenario. MUst be one of `step_based` or `custom_python`
* `definition::AbstractDict` the JSON definition of the scenario. Use `get_settings` on an 
        existing DSSScenario` object in order to get a sample definition object
returns: a `DSSScenario` handle to interact with the newly-created scenario
"""
function create_scenario(scenario_name::AbstractString, scenario_type::AbstractString, definition::AbstractDict, projectKey=get_projectKey())
    definition["name"] = scenario_name
    definition["type"] = scenario_type # step_based or custom_python
    scenario_id = request("POST", "projects/$(projectKey)/scenarios/", definition)["id"]
    return DSSScenario(scenario_id, projectKey)
end

struct DSSRun
    id::AbstractString
    triggerId::AbstractString
    scenarioId::AbstractString
    projectKey::AbstractString
end

export DSSRun

function run_scenario(scenario::DSSScenario, body::AbstractDict=Dict()) # you can send trigger parameters, not required
    runId = request("POST", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/run", body)["runId"]
    return DSSRun(runId, "manual", scenario.id, scenario.projectKey)
end

function get_details(run::DSSRun)
    request("GET", "projects/$(run.projectKey)/scenarios/$(run.scenarioId)/$(run.id)/")
end

abort_a_scenario(scenario::DSSScenario) = request("POST", "projects/$(scenario.projectKey)/scenarios/$(scenario.id)/abort")

function get_settings(run::DSSRun) 
    params = Dict("triggerRunId" => run.id,
                  "triggerId"    => run.triggerId)
    request("GET", "projects/$(run.projectKey)/scenarios/$(run.scenarioId)/get-run-for-trigger/"; params=params)["scenarioRun"]
end


# same than the ["trigger"] field of get_settings, not really useful

# function get_a_run_of_a_trigger(run::DSSRun)
#     request("GET", "projects/$(run.projectKey)/scenarios/trigger/$(run.scenarioId)/$(run.triggerId)?triggerRunId=$(run.id)")
# end

export get_status
export set_status
export get_payload
export set_payload
export create_scenario