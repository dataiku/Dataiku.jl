struct DSSProject <: DSSObject
    key::AbstractString
    DSSProject(project::AbstractString=get_projectKey()) = new(project)
end

macro project_str(str)
    DSSProject(str)
end

export @project_str
export DSSProject


function create_project(name::AbstractString, projectKey=uppercase(name), owner::AbstractString="admin")
    params = Dict(
        "projectKey" => projectKey,
        "name"       => name,
        "owner"      => owner
    )
    request("POST", "projects/", params)
    return DSSProject(projectKey)
end

function delete(project::DSSProject, dropData::Bool=false)
    request("DELETE", "projects/$(project.key)", params=Dict("dropData" => dropData))
end


get_metadata(project::DSSProject) = request("GET", "projects/$(project.key)/metadata")

get_settings(project::DSSProject) = request("GET", "projects/$(project.key)/settings")

get_permissions(project::DSSProject) = request("GET", "projects/$(project.key)/permissions")

get_variables(project::DSSProject) = request("GET", "projects/$(project.key)/variables")

get_tags(project::DSSProject) = request("GET", "projects/$(project.key)/tags")

function set_metadata(project::DSSProject, body::AbstractDict)
    request("PUT", "projects/$(project.key)/metadata", body)
end

function set_settings(project::DSSProject, body::AbstractDict)
    request("PUT", "projects/$(project.key)/settings", body)
end

function set_permissions(project::DSSProject, body::AbstractDict)
    request("PUT", "projects/$(project.key)/permissions", body)
end

function set_variables(project::DSSProject, body::AbstractDict)
    request("PUT", "projects/$(project.key)/variables", body)
end

function set_tags(project::DSSProject, body::AbstractDict)
    request("PUT", "projects/$(project.key)/tags", body)
end

function export_project(project::DSSProject; options...)
    request("GET", "projects/$(project.key)/export"; params=Dict(options), stream=true)
end

function export_project(project::DSSProject, output_file::AbstractString; options...)
    open(output_file; write=true) do file
        write(file, export_project(project; options...))
    end
end

function duplicate(project::DSSProject, new_name::AbstractString, new_key::AbstractString, duplication_mode="MINIMAL")
    body = Dict(
        "targetProjectName" => new_name,
        "targetProjectKey" => new_key,
        "duplicationMode" => duplication_mode
    )
    new_project_key = Dataiku.HttpUtils.request("POST", "projects/$(project.key)/duplicate/", body)["targetProjectKey"]
    return DSSProject(new_project_key)
end

####

list_projects(; tags=[]) = request("GET", "projects/"; params=Dict("tags" => tags))

export get_variables
export set_variables
export get_permissions
export set_permissions
export get_tags
export set_tags
export duplicate
export export_project
export list_projects