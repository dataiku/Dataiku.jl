"""
    get_definition(::DSSFolder)
    get_contents(::DSSFolder)
"""
struct DSSFolder <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSFolder(id::AbstractString, project::DSSProject=get_current_project()) = new(project, id)
end

macro folder_str(str)
    createobject(DSSFolder, str)
end

export @folder_str
export DSSFolder

list_managed_folders(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(projectKey)/managedfolders/")

function create_managed_folder(name::AbstractString, project::DSSProject=get_current_project();
    connection::AbstractString="filesystem_folders", path="$(project.key)/$(name)")
    body = Dict(
        "name"   => name,
        "params" => Dict(
            "connection" => connection,
            "path"       => path
        )
    )
    response = request_json("POST", "projects/$(project.key)/managedfolders/", body)
    DSSFolder(response["id"], project)
end

delete(folder::DSSFolder) = request_json("DELETE", "projects/$(folder.project.key)/managedfolders/$(folder.id)")

# get_definition might be better 
get_settings(folder::DSSFolder) = request_json("GET", "projects/$(folder.project.key)/managedfolders/$(folder.id)")


set_settings(folder::DSSFolder, settings::AbstractDict) =
    request_json("PUT", "projects/$(folder.project.key)/managedfolders/$(folder.id)", settings)

## Files

list_contents(folder::DSSFolder) = request_json("GET", "projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/")

download_file(folder::DSSFolder, path::AbstractString) =
    get_stream("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")

upload_file(folder::DSSFolder, file) =
    post_multipart("$(public_url)/projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/", file)

upload_file(folder::DSSFolder, file, filename) =
    post_multipart("$(public_url)/projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/", file, filename)

delete_file(folder::DSSFolder, path::AbstractString) =
    request_json("DELETE", "projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")