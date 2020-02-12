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

"""
```julia
make_project_key(project_name::AbstractString)
```
make a project key from a project label
"""
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