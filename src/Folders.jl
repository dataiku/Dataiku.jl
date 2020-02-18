"""
DSSFolder <: DSSObject

Representation of a ManagedFolder in DSS.

    list_managed_folders(::DSSFolder)
    list_contents(::DSSFolder)
"""
struct DSSFolder <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSFolder(id::AbstractString, project::DSSProject=get_current_project()) = new(project, id)
    DSSFolder(dict::AbstractDict) = new(d["projectKey"], d["id"])
end

macro folder_str(str)
    createobject(DSSFolder, str)
end

export @folder_str
export DSSFolder

list_managed_folders(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/managedfolders/")

function create_managed_folder(name, project::DSSProject=get_current_project(); connection="filesystem_folders", path="$(project.key)/$(name)")
    body = Dict(
        "name"   => name,
        "params" => Dict(
            "connection" => connection,
            "path"       => path
        )
    )
    create_managed_folder(body, project)
end

function create_managed_folder(body::AbstractDict, project::DSSProject=get_current_project())
    response = request_json("POST", "projects/$(project.key)/managedfolders/", body; show_msg=true)
    DSSFolder(response["id"], project)
end

delete(folder::DSSFolder) = delete_request("projects/$(folder.project.key)/managedfolders/$(folder.id)")


get_settings(folder::DSSFolder) = request_json("GET", "projects/$(folder.project.key)/managedfolders/$(folder.id)")

set_settings(folder::DSSFolder, settings::AbstractDict) =
    request_json("PUT", "projects/$(folder.project.key)/managedfolders/$(folder.id)", settings)


list_contents(folder::DSSFolder) = request_json("GET", "projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/")

function get_stream_from_file(f::Function, folder::DSSFolder, path)
    if _is_inside_recipe()
        get_flow_inputs(folder)
    end
    get_stream(f, "projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")
end

function get_file_content(folder::DSSFolder, path)
    ret = UInt8[]
    get_stream_from_file(folder, path) do io
        ret = read(io)
    end
    return ret
end

function download_file(folder::DSSFolder, path_in_folder, writing_path)
    open(writing_path, "w") do output
        get_stream_from_file(folder, path_in_folder) do input
            len = write(output, input)
            @info "$len bytes written to $writing_path"
        end
    end
end

function upload_file(folder::DSSFolder, file, filename)
    if _is_inside_recipe()
        get_flow_outputs(folder)
    end
    post_multipart("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/", file, filename)
end

function copy_file(ifolder::DSSFolder, ipath, ofolder::DSSFolder, opath=ipath)
    Dataiku.get_stream_from_file(ifolder, ipath) do io
        buf = Base.BufferStream()
        len = write(buf, io)
        @async Dataiku.upload_file(ofolder, IOContext(buf, :readerror=>false), opath)
        close(buf)
        @info "$len bytes copied to $opath in $ofolder"
    end
end

delete_file(folder::DSSFolder, path) = delete_request("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")