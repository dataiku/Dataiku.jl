"""
DSSFolder <: DSSObject

Representation of a ManagedFolder in DSS.
This object does not contain any data apart from its ID.

### functions
(the most important ones, not exhaustive list)

    * `list_managed_folders(::DSSFolder)`
    * `create_managed_folder(name)`
    * `get_settings(::DSSFolder)`
    * `list_contents(::DSSFolder)`
    * `get_stream_from_file(::DSSFolder)`
    * `delete(::DSSFolder)`
    * `get_stream_from_file(f::Function, ::DSSFolder)`
    * `get_file_content(::DSSFolder)`
    * `copy_file(::DSSFolder, input_path, ::DSSFolder, output_path)`
    * `upload_file(::DSSFolder, input_file, path)`
    * `delete_path(::DSSFolder, path)`
    * `clear_data(::DSSFolder)`
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

"""
`get_stream_from_file(f::Function, folder::DSSFolder, path)`

Get a stream from the file. A function must be provided. The stream is automatically closed at the end of the function.

#### Example
```julia
function print_file(folder::DSSFolder, file)
    Dataiku.get_stream_from_file(folder, file) do io
        println(String(read(io)))
    end
end
```
"""
function get_stream_from_file(f::Function, folder::DSSFolder, path)
    if _is_inside_recipe()
        get_flow_inputs(folder)
    end
    get_stream(f, "projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")
end

"""
`get_file_content(folder::DSSFolder, path)`

Returns the content of the file, as an array of bytes.
"""
function get_file_content(folder::DSSFolder, path)
    ret = UInt8[]
    get_stream_from_file(folder, path) do io
        ret = read(io)
    end
    return ret
end

"""
`download_file(folder::DSSFolder, path_in_folder, writing_path)`

Downloads a file to your local path.
"""
function download_file(folder::DSSFolder, path_in_folder, writing_path)
    open(writing_path, "w") do output
        get_stream_from_file(folder, path_in_folder) do input
            len = write(output, input)
            @info "$len bytes written to $writing_path"
        end
    end
end

function upload_file(folder::DSSFolder, file::IO, path="")
    if _is_inside_recipe()
        get_flow_outputs(folder)
    end
    post_multipart("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$path", file, basename(path))
end


"""
`upload_file(folder::DSSFolder, file, path="")`

Uploads `file` to the selected `path`. If `path` is empty, the file is uploaded at the root of the folder.
"""
function upload_file(folder::DSSFolder, file, path=basename(file))
    if isfile(file)
        upload_file(folder, open(file, read=true), path)
    else
        throw(DkuException("$file does not exist or is not a file.")) 
    end
end

"""
`copy_file(ifolder::DSSFolder, ipath, ofolder::DSSFolder, opath=ipath)`

Copies a file from a folder to another.
"""
function copy_file(ifolder::DSSFolder, ipath, ofolder::DSSFolder, opath=ipath)
    Dataiku.get_stream_from_file(ifolder, ipath) do io
        buf = Base.BufferStream()
        len = write(buf, io)
        @async Dataiku.upload_file(ofolder, IOContext(buf, :readerror => false), opath)
        close(buf)
        @info "$len bytes copied to $opath in $ofolder"
    end
end

"""
`delete_path(folder::DSSFolder, path)`

Delete a file or a subfolder.
"""
delete_path(folder::DSSFolder, path) = delete_request("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")

"""
`clear_data(folder::DSSFolder)`

Clear all the data in the folder.
"""
clear_data(folder::DSSFolder) = delete_path(folder, "/")