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
create_projectKey(project_name::AbstractString)
```
make a project key from a project label
"""
create_projectKey(name::AbstractString) = [l for l in name if isnumeric(l) || isletter(l) || l == '_'] |> join |> uppercase

function create_project(name::AbstractString, projectKey=create_projectKey(name), owner::AbstractString="admin")
    params = Dict(
        "projectKey" => projectKey,
        "name"       => name,
        "owner"      => owner
    )
    request_json("POST", "projects/", params)
    DSSProject(projectKey)
end

delete(project::DSSProject, dropData::Bool=false) =
    request_json("DELETE", "projects/$(project.key)", params=Dict("dropData" => dropData))

get_metadata(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/metadata")
set_metadata(project::DSSProject, body::AbstractDict) = set_metadata(body, project)
set_metadata(body::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/metadata", body)

get_settings(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/settings")
set_settings(project::DSSProject, body::AbstractDict) = set_settings(body, project)
set_settings(body::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/settings", body)

get_permissions(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/permissions")
set_permissions(project::DSSProject, body::AbstractDict) = set_permissions(body, project)
set_permissions(body::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/permissions", body)

get_variables(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/variables")
set_variables(project::DSSProject, body::AbstractDict) = set_variables(body, project)
set_variables(body::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/variables", body)

get_tags(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/tags")
set_tags(project::DSSProject, body::AbstractDict) = set_tags(body, project)
set_tags(body::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/tags", body)

export_project(project::DSSProject; options...) = get_stream("projects/$(project.key)/export"; params=Dict(options))

function export_project(project::DSSProject, output_file::AbstractString; options...)
    open(output_file; write=true) do file
        write(file, export_project(project; options...))
    end
end

function duplicate(project::DSSProject, new_name::AbstractString=get_metadata(project)["label"]*"_copy",
    new_key::AbstractString=create_projectKey(new_name), duplication_mode="MINIMAL")
    body = Dict(
        "targetProjectName" => new_name,
        "targetProjectKey" => new_key,
        "duplicationMode" => duplication_mode
    )
    new_project_key = request_json("POST", "projects/$(project.key)/duplicate/", body)["targetProjectKey"]
    DSSProject(new_project_key)
end


list_projects(; tags=[]) = request_json("GET", "projects/"; params=Dict("tags" => tags))