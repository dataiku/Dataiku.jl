"""
    get_definition(::DSSFolder)
    get_contents(::DSSFolder)
"""
struct DSSFolder <: DSSObject
    id::AbstractString
    projectKey::AbstractString
    DSSFolder(id::AbstractString, projectKey=get_projectKey()) = new(id, projectKey)
end

macro folder_str(str)
    createobject(DSSFolder, str)
end

export @folder_str
export DSSFolder

list_managed_folders(projectKey=get_projectKey()) = request("GET", "projects/$(projectKey)/managedfolders/")

function create_managed_folder(name::AbstractString, projectKey=get_projectKey();
                               connection::AbstractString="filesystem_folders",
                               path::AbstractString="$(projectKey)/$(name)")
    body = Dict(
        "name"   => name,
        "params" => Dict(
            "connection" => connection,
            "path"       => path
        )
    )
    response = request("POST", "projects/$(projectKey)/managedfolders/", body)
    return DSSFolder(response["id"])
end

delete(folder::DSSFolder) = request("DELETE", "projects/$(folder.projectKey)/managedfolders/$(folder.id)")


function get_settings(folder::DSSFolder) # get_definition might be better
    request("GET", "projects/$(folder.projectKey)/managedfolders/$(folder.id)")
end

function set_settings(folder::DSSFolder, settings::AbstractDict)
    request("PUT", "projects/$(folder.projectKey)/managedfolders/$(folder.id)", settings)
end

## Files

function list_contents(folder::DSSFolder)
    request("GET", "projects/$(folder.projectKey)/managedfolders/$(folder.id)/contents/")
end

function download_file(folder::DSSFolder, path::AbstractString)
    data = request("GET", "projects/$(folder.projectKey)/managedfolders/$(folder.id)/contents/$(path)"; parse_json=true)
    IOBuffer(data)
end

upload_file(folder::DSSFolder, path::AbstractString, filename::AbstractString=path) = upload_file(folder, open(path; read=true), filename)

function upload_file(folder::DSSFolder, file::IO, filename::AbstractString)
    post_multipart("$(public_url)/projects/$(folder.projectKey)/managedfolders/$(folder.id)/contents/", file, filename)
end

function delete_file(folder::DSSFolder, path::AbstractString)
    request("DELETE", "projects/$(folder.projectKey)/managedfolders/$(folder.id)/contents/$(path)")
end

export list_contents
export download_file
export upload_file
export delete_file