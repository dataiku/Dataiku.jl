struct DSSMacro <: DSSObject
    projectKey::DSSProject
    id::AbstractString
    DSSMacro(id::AbstractString, project::DSSProject=get_current_project()) = new(projectKey, id)
end

macro macro_str(str)
    createobject(DSSMacro, str)
end

export @macro_str
export DSSMacro

struct DSSMacroRun
    dssmacro::DSSMacro
    id::AbstractString
end
export DSSMacro

list_macros(project::DSSProject=get_current_project()) =  request_json("GET", "projects/$(project.key)/runnables/")

get_definition(dssmacro::DSSMacro) =
    request_json("GET", "projects/$(project.key)/runnables/$(dssmacro.id)")

function run_macro(dssmacro::DSSMacro, wait::Bool=false; params::AbstractDict=Dict(), adminParams::AbstractDict=Dict())
    body = Dict("params"      => params,
                "adminParams" => adminParams)
    res = request_json("POST", "projects/$(dssmacro.project.key)/runnables/$(dssmacro.id)?wait=$(wait)", body)
    DSSMacroRun(dssmacro, res["runId"])
end

get_state(run::DSSMacroRun) = request_json("GET", "projects/$(run.dssmacro.project.key)/runnables/$(run.dssmacro.id)/state/$(run.id)")

function retrieve_result(run::DSSMacroRun)
    response = request("GET", "projects/$(run.dssmacro.project.key)/runnables/$(run.dssmacro.id)/result/$(run.id)")
    display("text/html", response)
    response
end

abort(run::DSSMacroRun) = request_json("POST", "projects/$(run.dssmacro.project.key)/runnables/$(run.dssmacro.id)/abort/$(run.id)")