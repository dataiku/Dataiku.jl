"""
`DSSProject <: DSSObject`

Representation of a Project in DSS.
This object does not contain any data apart from its ID.

Can be created using project_str macro :
- `project"PROJECTKEY"`

### functions
(the most important ones, not exhaustive list)

* `list_projects()`
* `create_project(name, projectKey, owner)`
* `delete(::DSSProject)`
* `get_current_project()`
* `set_current_project(::DSSProject)`
* `get_variables(::DSSProject)`
"""
struct DSSProject <: DSSObject
    key::AbstractString
    DSSProject(projectKey::AbstractString) = new(projectKey)
    DSSProject() = get_current_project()
end

macro project_str(str)
    DSSProject(str)
end

export @project_str
export DSSProject


make_project_key(name::AbstractString) = [l for l in name if isnumeric(l) || isletter(l) || l == '_'] |> join |> uppercase

function create_project(name::AbstractString, projectKey=make_project_key(name), owner::AbstractString="admin")
    params = Dict(
        "projectKey" => projectKey,
        "name"       => name,
        "owner"      => owner
    )
    request_json("POST", "projects/", params; show_msg=true)
    DSSProject(projectKey)
end

function exists(project::DSSProject)
    for p in list_projects()
        if p["projectKey"] == project.key
            return true
        end
    end
    return false
end

delete(project::DSSProject, dropData::Bool=false) = delete_request("projects/$(project.key)", params=Dict("dropData" => dropData))

get_variables(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/variables")
set_variables(project::DSSProject, body::AbstractDict) = set_variables(body, project)
set_variables(body::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/variables", body)

list_projects(; tags=[]) = request_json("GET", "projects/"; params=Dict("tags" => tags))

function get_current_project()
    if !haskey(ENV, "DKU_CURRENT_PROJECT_KEY")
        if isinteractive()
            println("No projectKey found, define current project with Dataiku.set_current_project(::DSSProject)")
            set_current_project()
        else
            throw(DkuException("No projectKey found, define current project with Dataiku.set_current_project(::DSSProject)"))
        end
    end
    DSSProject(ENV["DKU_CURRENT_PROJECT_KEY"])
end

"""
`set_current_project()`

Provides a list of all projects and let user define the current project interactively.
Can be used in a julia REPL or notebook only.
"""
function set_current_project()
    if !isinteractive()
        throw(DkuException("Cannot interactively define project key."))
    end
    while true
        println("Existing projects:")
        for project in list_projects()
            println(project["projectKey"])
        end
        print("enter projectKey (empty for aborting): ")
        project = DSSProject(readline(stdin))
        if isempty(project.key)
            throw(DkuException("No projectKey found, define current project with Dataiku.set_current_project(::DSSProject)"))
        elseif exists(project)
            return set_current_project(project)
        else
            println("Project \'$(project.key)\' doesn't exist or you don't have permissions to access it.")
        end
    end
end

"""
`set_current_project(project::DSSProject)`

Define the `current project` to work on.

All the DSS objects created after settings the `current project` will be by default linked to this project
"""
function set_current_project(project::DSSProject)
    if exists(project)
        ENV["DKU_CURRENT_PROJECT_KEY"] = project.key
        @info "Current project set to \'$(project.key)\'"
    else
        throw(DkuException("Project \'$(project.key)\' doesn't exist or you don't have permissions to access it."))
    end
end