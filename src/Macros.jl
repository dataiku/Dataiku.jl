struct DSSMacro <: DSSObject
    id::AbstractString
    projectKey::AbstractString
    DSSMacro(id::AbstractString, projectKey=get_projectKey()) = new(id, projectKey)
end

macro macro_str(str)
    createobject(DSSMacro, str)
end

export @macro_str
export DSSMacro

struct DSSMacroRun
    id::AbstractString
    macroId::AbstractString
    projectKey::AbstractString
end

list_macros(projectKey=get_projectKey()) =  request("GET", "projects/$(projectKey)/runnables/")

function get_settings(dssmacro::DSSMacro) # get_definition might be better
    request("GET", "projects/$(projectKey)/runnables/$(dssmacro.id)")
end

function run_macro(dssmacro::DSSMacro, wait::Bool=false; params::AbstractDict=Dict(), adminParams::AbstractDict=Dict())
    body = Dict("params"      => params,
                "adminParams" => adminParams)
    runId = request("POST", "projects/$(dssmacro.projectKey)/runnables/$(dssmacro.id)?wait=$(wait)", body)["runId"]
    return DSSMacroRun(runId, dssmacro.id, dssmacro.projectKey)
end

get_state(run::DSSMacroRun) = request("GET", "projects/$(run.projectKey)/runnables/$(run.macroId)/state/$(run.id)")

function retrieve_result(run::DSSMacroRun)
    response = request("GET", "projects/$(run.projectKey)/runnables/$(run.macroId)/result/$(run.id)"; parse_json=false)
    display("text/html", response)
end

abort(run::DSSMacroRun) = request("POST", "projects/$(run.projectKey)/runnables/$(run.macroId)/abort/$(run.id)")