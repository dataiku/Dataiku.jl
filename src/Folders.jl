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
    * `get_download_stream(f::Function, ::DSSFolder)`
    * `delete(::DSSFolder)`
    * `get_file_content(::DSSFolder, path)`
    * `read_json(folder::DSSFolder, path)`
    * `read_json(folder::DSSFolder, path, data)`
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
`get_download_stream(f::Function, folder::DSSFolder, path)`

Get a stream from the file. A function must be provided. The stream is automatically closed at the end of the function.

#### Example
```julia
Dataiku.get_download_stream(folder, file) do io
    println(String(read(io)))
end
```
"""
function get_download_stream(f::Function, folder::DSSFolder, path)
    _check_inputs(folder)
    get_stream(f, "projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")
end

"""
`get_download_stream(folder::DSSFolder, path)`

Get a stream from the file.

#### Example
```julia
io = Dataiku.get_download_stream(folder, file)
while !eof(io)
    println(readline(io))
end
```
"""
function get_download_stream(folder::DSSFolder, path)
    _check_inputs(folder)
    get_stream("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$(path)")
end


"""
`get_file_content(folder::DSSFolder, path)`

Returns the content of the file, as an array of bytes.
"""
function get_file_content(folder::DSSFolder, path)
    ret = UInt8[]
    get_download_stream(folder, path) do io
        ret = read(io)
    end
    return ret
end

"""
`read_json(folder::DSSFolder, path)`

Returns the content of the file, as a Dict.
"""
read_json(folder::DSSFolder, path) = get_file_content(folder, path) |> String |> JSON.parse

"""
`write_json(folder::DSSFolder, path, obj::AbstractDict)`

Returns the content of the file, as an array of bytes.
"""
write_json(folder::DSSFolder, path, obj::AbstractDict) = upload_data(folder, path, JSON.json(obj, 2))

"""
`download_file(folder::DSSFolder, path_in_folder, local_path)`

Downloads a file to your local path.
"""
function download_file(folder::DSSFolder, path_in_folder, local_path)
    open(local_path, "w") do output
        get_download_stream(folder, path_in_folder) do input
            len = write(output, input)
            @info "$len bytes written to $local_path"
        end
    end
end

"""
`upload_data(folder::DSSFolder, path, data)`

Uploads data to a specific path in the managed folder.
If the file already exists, it will be replaced.
"""
upload_data(folder::DSSFolder, path, data) = upload_stream(folder, path, IOBuffer(data))

"""
`upload_stream(folder::DSSFolder, path, file::IO)`

Uploads the content of a stream object to a specific path in the managed folder.
If the file already exists, it will be replaced.
"""
function upload_stream(folder::DSSFolder, path, file::IO)
    _check_outputs(folder)
    post_multipart("projects/$(folder.project.key)/managedfolders/$(folder.id)/contents/$path", path, file)
end

"""
`upload_file(folder::DSSFolder, path, file_path)`

Uploads the content of the file to a specific path in the managed folder.
If the file already exists, it will be replaced.
"""
function upload_file(folder::DSSFolder, path, file_path)
    if isfile(file_path)
        upload_stream(folder, path, open(file_path, read=true))
    else
        throw(DkuException("$file_path does not exist or is not a file.")) 
    end
end

"""
`copy_file(ifolder::DSSFolder, ipath, ofolder::DSSFolder, opath=ipath)`

Copies a file from a folder to another.
"""
function copy_file(ifolder::DSSFolder, ipath, ofolder::DSSFolder, opath=ipath)
    res = nothing
    Dataiku.get_download_stream(ifolder, ipath) do io
        buf = Base.BufferStream()
        @async begin 
            write(buf, io)
            close(buf)
        end
        res = Dataiku.upload_stream(ofolder, opath, IOContext(buf, :readerror => false))
    end
    res
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