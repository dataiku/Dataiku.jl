using DataFrames
using Dates
using CSVFiles

"""
```julia
struct DSSDataset <: DSSObject
    project::DSSProject
    name::AbstractString
    DSSDataset(name::AbstractString, project::DSSProject=get_current_project()) = new(project, name)
end
```
Can be created using dataset_str macro :
- `dataset"datasetName"` if you are inside DSS
- `dataset"PROJECTKEY.datasetName"` if you are outside of DSS or want to have dataset from another project
"""
struct DSSDataset <: DSSObject
    project::DSSProject
    name::AbstractString
    DSSDataset(name::AbstractString, project::DSSProject=get_current_project()) = new(project, name)
end

macro dataset_str(str)
    createobject(DSSDataset, str)
end

export @dataset_str
export DSSDataset

const DKU_DATE_FORMAT = dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"

## make CSVFiles.jl parser recognize this dateformat during type inference
__init__() = push!(CSVFiles.TextParse.common_datetime_formats, DKU_DATE_FORMAT)

## make CSVFiles writer write dates in the right format
CSVFiles._writevalue(io::IO, value::DateTime, delim, quotechar, escapechar, nastring) = print(io, Dates.format(value, DKU_DATE_FORMAT))

###################################################
#
#   READING FUNCTIONS
#
###################################################

"""
```julia
function get_dataframe(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
```

get the data of a dataset in a DataFrame

### Keywords parameters
- `partitions::AbstractArray` : specify the partitions wanted
- `infer_types::Bool=true` : uses the types detected by TextParse.jl rather than the DSS schema
- `limit::Integer` : Limits the number of rows returned
- `ratio::AbstractFloat` : Limits the ratio to at n% of the dataset
- `sampling::AbstractString="head"` : Sampling method, if
    * `head` returns the first rows of the dataset. Incompatible with ratio parameter.
    * `random` returns a random sample of the dataset
    * `random-column` returns a random sample of the dataset. Incompatible with limit parameter.
- `sampling_column::AbstractString` : Select the column used for "columnwise-random" sampling

### examples
```julia
get_dataframe(dataset"myDataset")
get_dataframe(dataset"myDataset", [:col1, :col2, :col5]; partitions=["2019-02", "2019-03"])
get_dataframe(dataset"PROJECTKEY.myDataset"; infer_types=false, limit=200, sampling="random")
```
"""
function get_dataframe(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
    stream, names, types = get_dataframe_params(ds, columns; kwargs...)
    load(CSVFiles.Stream(format"TSV", stream); header_exists=false, colnames=names, colparsers=types) |> DataFrame
end

iter_data_chunks(ds::DSSDataset, columns::AbstractArray=[]; kwargs...) =
    Channel(chnl->_iter_data_chunks(chnl, get_dataframe_params(ds, columns; kwargs...)...))

function get_dataframe_params(ds::DSSDataset, columns::AbstractArray=[]; partitions::AbstractArray=[], infer_types=true, kwargs...)
    sampling = create_sampling_argument(; kwargs...) |> JSON.json
    schema = get_schema(ds)["columns"]
    stream = get_data_stream(ds; columns=columns, format="tsv-excel-noheader", sampling=sampling, partitions=partitions)
    names = get_column_names(schema, columns)
    types = infer_types ? [] : get_column_types(schema, columns)
    stream, names, types
end

function _iter_data_chunks(chnl::AbstractChannel, io::IO, names::AbstractArray, types)
    first_line = ""
    last_is_quote = false
    while !eof(io)
        data = readavailable(io) # use `data = Array{UInt8}(undef, X)` and `readbytes!(io, data, X)` to read only X bytes, can cause bug at last chunk
        chunk, last_line, last_is_quote = split_last_line(String(data), last_is_quote)
        df = load(CSVFiles.Stream(format"TSV", IOBuffer(first_line * chunk)); header_exists=false, colnames=names) |> DataFrame
        first_line = last_line
        put!(chnl, df)
    end
end

iter_rows(ds::DSSDataset, columns::AbstractArray=[]; kwargs...) = Channel(chnl->_iter_rows(chnl, iter_data_chunks(ds, columns; kwargs...)))

function _iter_rows(chnl::AbstractChannel, chunks::AbstractChannel)
    for chunk in chunks
        for row in eachrow(chunk)
            put!(chnl, row)
        end
    end
end

 # TODO dont work for smaller than chunk df
function iter_dataframes(ds::DSSDataset, nrows::Integer=10_000, columns::AbstractArray=[]; kwargs...)
    chunks = iter_data_chunks(ds, columns; kwargs...)
    Channel(chnl->_iter_dataframes(chnl, chunks, nrows))
end

function _iter_dataframes(chnl::AbstractChannel, chunks::AbstractChannel, n::Integer)
    df = take!(chunks)
    for chunk in chunks
        for i in n:n:nrow(df)
            put!(chnl, df[1:n, :])
            df = df[n+1:end, :]
        end
        append!(df, chunk)
    end
    for i in n:n:nrow(df)
        put!(chnl, df[1:n, :])
        df = df[n+1:end, :]
    end
    put!(chnl, df)
end

iter_tuples(ds::DSSDataset, columns::AbstractArray=[]; kwargs...) = Channel(chnl->_iter_tuples(chnl, iter_data_chunks(ds, columns; kwargs...)))

# TODO make this more efficient if possible
function _iter_tuples(chnl::AbstractChannel, chunks::AbstractChannel)
    for chunk in chunks
        for row in 1:nrow(chunk)
            put!(chnl, Tuple([chunk[row,col] for col in 1:ncol(chunk)]))
        end
    end
end

function get_data_params(ds::DSSDataset; kwargs...)
    params = Dict(kwargs)
    if !(haskey(params,:partitions) && !isempty(params[:partitions])) && !runs_remotely()
        params[:partitions] = get(get_flow_inputs(ds), "partitions", "")
    end
    params
end

get_data_json(ds::DSSDataset; kw...)    = request_json(     "GET", "projects/$(ds.project.key)/datasets/$(ds.name)/data"; params=get_data_params(ds; kw...))
get_data_stream(ds::DSSDataset; kw...)  = request_stream(   "GET", "projects/$(ds.project.key)/datasets/$(ds.name)/data"; params=get_data_params(ds; kw...))
get_data(ds::DSSDataset; kw...)         = request(          "GET", "projects/$(ds.project.key)/datasets/$(ds.name)/data"; params=get_data_params(ds; kw...))

###################################################
#
#   WRITING FUNCTIONS
#
###################################################

function write_with_schema(ds::DSSDataset, df::AbstractDataFrame; kwargs...)
    schema = write_schema_from_dataframe(ds, df)
    write_from_dataframe(ds, df, schema; kwargs...)
end

function write_from_dataframe(ds::DSSDataset, df::AbstractDataFrame, schema=get_schema_from_df(df); kwargs...)
    id = init_write_session(ds, schema; kwargs...)
    task = @async wait_write_session(id)
    push_data(id, df, ds)
    Base.wait(task) # Making sure wait_write_session thread is done
end

function write_schema_from_dataframe(ds::DSSDataset, df::AbstractDataFrame)
    schema = get_schema_from_df(df)
    set_schema(ds, schema)
    schema
end

function init_write_session(ds::DSSDataset, schema::AbstractDict; method="STREAM", partition="", writeMode="OVERWRITE")
    req = Dict(
        "method"          => method,
        "partitionSpec"   => (partition == "" && !runs_remotely()) ? get(get_flow_outputs(ds), "partition", "") : partition,
        "fullDatasetName" => full_name(ds),
        "writeMode"       => writeMode,
        "dataSchema"      => schema)
    request_json("POST", "datasets/init-write-session/", Dict("request" => JSON.json(req)); intern_call=true)["id"]
end

function wait_write_session(id::AbstractString)
    res = request_json("GET", "datasets/wait-write-session/?id=" * id; intern_call=true)
    if res["ok"]
        println("$(res["writtenRows"]) rows successfully written ($id)")
    else
        throw(ErrorException("An error occurred during dataset write ($id): $(res["message"])"))
    end
end

push_data(id::AbstractString, df::AbstractDataFrame, ds::DSSDataset) =
    request("POST", "datasets/push-data/?id=$(id)", get_stream_write(df); intern_call=true)

function get_stream_write(df::AbstractDataFrame)
    io = Base.BufferStream()
    @async begin save(CSVFiles.Stream(format"CSV", io), df; nastring="", header=false, escapechar='"')
        close(io)
    end
    io
end

###################################################
#
#   UTILITY FUNCTIONS
#
###################################################

get_flow_outputs(ds::DSSDataset) = get_flow_inputs_or_outputs(ds, "out")

get_flow_inputs(ds::DSSDataset) = get_flow_inputs_or_outputs(ds, "in")

function get_flow_inputs_or_outputs(ds::DSSDataset, option)
    puts = find_field(get_flow()[option], "fullName", full_name(ds))
    if puts == nothing
        throw(ArgumentError("Dataset isn't an " * option * "put of the recipe"))
    end
    puts
end

get_column_types(ds::DSSDataset, columns::AbstractArray=[]) = get_column_types(get_schema(ds)["columns"], columns)

get_column_types(schema::AbstractArray, cols::AbstractArray=[]) =
    [col["name"] => string_to_type(col["type"]) for col in schema if isempty(cols) || Symbol(col["name"]) in cols] |> Dict

get_column_names(ds::DSSDataset, columns::AbstractArray=[]) = get_column_names(get_schema(ds)["columns"], columns)

get_column_names(schema::AbstractArray, columns::Nothing=nothing) = [Symbol(col["name"]) for col in schema]

get_column_names(schema::AbstractArray, columns::AbstractArray) = isempty(columns) ? get_column_names(schema) : columns

const DKU_DF_TYPE_MAP = Dict(
    "string"   => String,
    "tinyint"  => Int8,
    "smallint" => Int16,
    "int"      => Int32,
    "bigint"   => Int64,
    "float"    => Float32,
    "double"   => Float64,
    "boolean"  => Bool,
    "date"     => DateTime
)

string_to_type(str) = get(DKU_DF_TYPE_MAP, str, String)

function type_to_string(coltype)
    for (name, typename) in DKU_DF_TYPE_MAP
        if typename == "date"
            return "string"
        end
        if typename <: coltype
            return name
        end
    end
    "string"
end

# remove the last incomplete line of the chunk
function split_last_line(str::AbstractString, last_is_quote::Bool=false, quotechar='\"')
    inquote = last_is_quote = count(i -> (i == quotechar), str) % 2 == 1 ⊻ last_is_quote # Check if the end of the string is inquote
    for i in Iterators.reverse(eachindex(str))
        if !inquote && str[i] == '\n'
            return str[1:i], str[nextind(str, i):end], last_is_quote
        elseif str[i] == quotechar
            inquote = !inquote
        end
    end
    str, "", last_is_quote
end

function get_schema_from_df(df::AbstractDataFrame)
    new_columns = Any[]
    for name in names(df)
        new_column = Dict("name" => String(name),
                          "type" => type_to_string(eltype(df[Symbol(name)])))
        push!(new_columns, new_column)
    end
    Dict("columns" => new_columns, "userModified" => false)
end

"""
    sampling_column::Symbol
    limit::Integer
    ratio::AbstractFloat
"""
function create_sampling_argument(; sampling::String="head", sampling_column=nothing, limit=nothing, ratio=nothing)
    if sampling_column != nothing && sampling != "random-column"
        throw(ArgumentError("sampling_column argument does not make sense with $(sampling) sampling method"))
    end
    if sampling == "head"
        if ratio != nothing
            throw(ArgumentError("target_ratio parameter is not supported by the head sampling method"))
        elseif limit == nothing
            return Dict("samplingMethod" => "FULL")
        else
            return Dict("samplingMethod" => "HEAD_SEQUENCIAL",
                        "maxRecords"     => limit)
        end
    elseif sampling == "random"
        if ratio != nothing
            if limit != nothing
                throw(ArgumentError("Cannot set both ratio and limit"))
            else
                return Dict("samplingMethod" => "RANDOM_FIXED_RATIO",
                            "targetRatio"    => ratio)
            end
        elseif limit != nothing
            return Dict("samplingMethod" => "RANDOM_FIXED_NB",
                        "maxRecords"     => limit)
        else
            throw(ArgumentError("Sampling method random requires either a parameter limit or ratio"))
        end
    elseif sampling == "random-column"
        if sampling_column == nothing
            throw(ArgumentError("random-column sampling method requires a sampling_column argument"))
        elseif ratio != nothing
            throw(ArgumentError("ratio parameter is not handled by sampling column method"))
        elseif limit == nothing
            throw(ArgumentError("random-column requires a limit parameter"))
        end
        return Dict("samplingMethod" => "COLUMN_BASED",
                    "maxRecords"     => limit,
                    "column"         => sampling_column)
    else
        throw(ArgumentError("Sampling $(sampling) is unsupported"))
    end
end

###################################################
#
#   API FUNCTIONS
#
###################################################

function create_dataset(name::AbstractString, project::DSSProject=get_current_project();
        dataset_type="Filesystem",
        connection="filesystem_managed",
        formatType="csv",
        style="excel")
    body = Dict(
        "projectKey"   => project.key,
        "name"         => name,
        "type"         => dataset_type,
        "formatType"   => formatType,
        "params"       => Dict(
            "connection" => connection,
            "path"       => project.key * "/" * name
        ),
        "formatParams" => Dict(
            "style"      => style,
            "separator"  => "\t"
        )
    )
    create_dataset(body, project)
    DSSDataset(name, project)
end

function create_dataset(body::AbstractDict, project::DSSProject=get_current_project())
    request_json("POST", "projects/$(project.key)/datasets/", body)
    DSSDataset(body["name"], project)
end

delete(ds::DSSDataset; dropData::Bool=false) = request_json("DELETE", "projects/$(ds.project.key)/datasets/$(ds.name)"; params=Dict("dropData" => dropData))


"""
    function list_datasets(project::DSSProject=get_current_project(); foreign=false, tags::AbstractArray=[])
"""
list_datasets(project::DSSProject=get_current_project(); kwargs...) = request_json("GET", "projects/$(project.key)/datasets/"; params=kwargs)

get_settings(ds::DSSDataset) = request_json("GET", "projects/$(ds.project.key)/datasets/$(ds.name)")

set_settings(ds::DSSDataset, body::AbstractDict) = request_json("PUT", "projects/$(ds.project.key)/datasets/$(ds.name)", body)


get_metadata(ds::DSSDataset) = request_json("GET", "projects/$(ds.project.key)/datasets/$(ds.name)/metadata")

set_metadata(ds::DSSDataset, body::AbstractDict) = request_json("PUT", "projects/$(ds.project.key)/datasets/$(ds.name)/metadata", body)


get_schema(ds::DSSDataset) = request_json("GET", "projects/$(ds.project.key)/datasets/$(ds.name)/schema")

set_schema(ds::DSSDataset, body::AbstractDict) = request_json("PUT", "projects/$(ds.project.key)/datasets/$(ds.name)/schema", body)


list_partitions(ds::DSSDataset) = request_json("GET", "projects/$(ds.project.key)/datasets/$(ds.name)/partitions")

clear_data(ds::DSSDataset, partitions::AbstractArray=[]) =
    request_json("DELETE", "projects/$(ds.project.key)/datasets/$(ds.name)/data"; params=Dict("partitions" => partitions))


get_last_metric_values(ds::DSSDataset, partition::AbstractString="NP") =
    request_json("GET", "projects/$(ds.project.key)/datasets/$(ds.name)/metrics/last/$(partition)")


get_single_metric_history(ds::DSSDataset, metricLookup::AbstractString, partition::AbstractString="NP") =
    request_json("GET", "projects/$(ds.project.key)/datasets/$(ds.name)/metrics/history/$(partition)?metricLookup=$(metricLookup)")



list_meanings() = request_json("GET", "meanings/")

get_meaning_definition(meaningId::AbstractString) = request_json("GET", "meanings/$(meaningId)")

update_meaning_definition(definition::AbstractDict, meaningId::AbstractString) = request_json("PUT", "meanings/$(meaningId)", definition)

create_meaning(data::AbstractDict) = request_json("POST", "meanings/", data)



list_api_services(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/apiservices/")

list_packages(serviceId::AbstractString, project::DSSProject=get_current_project()) =
    request_json("GET", "projects/$(project.key)/apiservices/$(serviceId)/packages/")

delete_package(serviceId::AbstractString, packageId::AbstractString, project::DSSProject=get_current_project()) =
    request_json("DELETE", "projects/$(project.key)/apiservices/$(serviceId)/packages/$(packageId)")

download_package_archive(serviceId::AbstractString, packageId::AbstractString, project::DSSProject=get_current_project()) =
    request_stream("GET", "projects/$(project.key)/apiservices/$(serviceId)/packages/$(packageId)/archive")


get_wiki(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/wiki/")

update_wiki(wiki::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/wiki/", wiki)

get_article(articleId::AbstractString, project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/wiki/$(articleId)")

update_article(article::AbstractDict, articleId, project::DSSProject=get_current_project()) =
    request_json("PUT", "projects/$(project.key)/wiki/$(articleId)", article)

function create_article(name::AbstractString, project::DSSProject=get_current_project(); parent=nothing)
    data = Dict(
        "projectKey" => project.key,
        "id"         => name
    )
    if parent != nothing data["parent"] = parent end
    request_json("POST", "projects/$(project.key)/wiki/", data)
end


get_discussions(objectId::AbstractString, objectType::AbstractString, project::DSSProject=get_current_project()) =
    request_json("GET", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/")

get_discussion(objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, project::DSSProject=get_current_project()) =
    request_json("GET", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/$(discussionId)")

update_discussion(discussion::AbstractDict, objectId::AbstractString, objectType, discussionId, project::DSSProject=get_current_project()) =
    request_json("PUT", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/$(discussionId)", discussion)

function create_discussion(objectId::AbstractString, objectType::AbstractString, topic, reply, project::DSSProject=get_current_project())
    data = Dict(
        "topic" => topic,
        "reply" => reply
    )
    request_json("POST", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/", data)
end

reply(objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, reply, project::DSSProject=get_current_project()) =
    request_json("POST", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/$(discussionId)/replies/", Dict("reply" => reply))


compute_metrics(ds::DSSDataset, data::AbstractDict; partitions::AbstractArray=[]) =
    request_json("POST", "projects/$(ds.project.key)/datasets/$(ds.name)/actions/computeMetrics/", data; params=Dict(:partitions => partitions))

run_checks(ds::DSSDataset, data::AbstractDict; partitions::AbstractArray=[]) =
    request_json("POST", "projects/$(ds.project.key)/datasets/$(ds.name)/actions/runChecks/"; params=Dict(:partitions => partitions))

##################################################################################


# function push_to_git_remote(remote::Union{Nothing, String}, project::DSSProject=get_current_project())
# 	request_json("POST", "projects/$(project.key)/actions/push-to-git-remote", Dict())
# end

# function get_data_alternative_version(ds::DSSDataset)
# 	request_json("POST", "projects/$(project.key)/datasets/$(ds.name)/data", Dict())
# end


# function synchronize_hive_metastore(ds::DSSDataset)
# 	request_json("POST", "projects/$(project.key)/datasets/$(ds.name)/actions/synchronizeHiveMetastore", Dict())
# end

# function update_from_hive_metastore(ds::DSSDataset)
# 	request_json("POST", "projects/$(project.key)/datasets/$(ds.name)/actions/updateFromHive", Dict())
# end


# function generate_package(serviceId::Union{Nothing, String}, packageId::Union{Nothing, String})
# 	request_json("POST", "projects/$(project.key)/apiservices/$(serviceId)/packages/$(packageId)", Dict())
# end


##################################################################################