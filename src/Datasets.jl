using DataFrames
using Dates
using CSVFiles

"""
## TEST
```julia
    ds = DSSDataset("datasetName", "projectKey")
    df = get_dataframe(ds)
```
#### or
```julia
    df = get_dataframe(dataset"datasetName")
```
- ceci est un `example`
- test
- test2
"""
struct DSSDataset <: DSSObject
    name::AbstractString
    projectKey::AbstractString
    DSSDataset(name::AbstractString, projectKey=get_projectKey()) = new(name, projectKey)
end

macro dataset_str(str)
    createobject(DSSDataset, str)
end

export @dataset_str
export DSSDataset

__init__() = push!(CSVFiles.TextParse.common_datetime_formats, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")

###################################################
#
#   READING FUNCTIONS
#
###################################################

function get_dataframe_params(ds::DSSDataset, columns::AbstractArray=[]; partitions::AbstractArray=[], infer_types=true, kwargs...)
    sampling = create_sampling_argument(; kwargs...) |> JSON.json
    stream = get_data(ds; columns=columns, format="tsv-excel-noheader", sampling=sampling, partitions=partitions, stream=true)
    schema = get_schema(ds)["columns"]
    names = get_column_names(schema, columns)
    types = infer_types ? [] : get_column_types(schema, columns)
    return stream, names, types
end

function get_dataframe(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
    stream, names, types = get_dataframe_params(ds, columns; kwargs...)
    load(CSVFiles.Stream(format"TSV", stream); header_exists=false, colnames=names, colparsers=types) |> DataFrame
end

function iter_data_chunks(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
    stream, names, types = get_dataframe_params(ds, columns; kwargs...)
    Channel(chnl->_iter_data_chunks(chnl, stream, names, types))
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

function iter_rows(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
    chunks = iter_data_chunks(ds, columns; kwargs...)
    Channel(chnl->_iter_rows(chnl, chunks))
end

function _iter_rows(chnl::AbstractChannel, chunks::AbstractChannel)
    for chunk in chunks
        for row in eachrow(chunk)
            put!(chnl, row)
        end
    end
end

function iter_dataframes(ds::DSSDataset, nrows::Integer=10_000, columns::AbstractArray=[]; kwargs...) # dont work for smaller than chunk df
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
    return df
end

iter_tuples(ds::DSSDataset, columns::AbstractArray=[]; kwargs...) = Channel(chnl->_iter_tuples(chnl, iter_data_chunks(ds, columns; kwargs...)))

# TODO
function _iter_tuples(chnl::AbstractChannel, chunks::AbstractChannel)
    for chunk in chunks
        for row in 1:nrow(chunk)
            put!(chnl, Tuple([chunk[row,col] for col in 1:ncol(chunk)]))
        end
    end
end

###################################################
#
#   WRITING FUNCTIONS
#
###################################################

function get_schema_from_df(df::AbstractDataFrame)
    new_columns = Any[]
    for name in names(df)
        new_column = Dict("name" => string(name),
                          "type" => type_to_string(eltype(df[Symbol(name)])))
        push!(new_columns, new_column)
    end
    Dict("columns" => new_columns, "userModified" => false)
end

function write_schema(ds::DSSDataset, schema::AbstractDict)
    request("PUT", "projects/$(ds.projectKey)/datasets/$(ds.name)/schema", schema)
end

write_schema_from_dataframe(ds::DSSDataset, df::AbstractDataFrame) = write_schema(ds, get_schema_from_df(df))

function init_write_session(schema::AbstractDict, fullname::AbstractString)
    req = Dict(
        "method"          => "STREAM",
        "partitionSpec"   => "",
        "fullDatasetName" => fullname,
        "writeMode"       => "OVERWRITE",
        "dataSchema"      => schema)
    id = request("POST", "datasets/init-write-session/", Dict("request" => JSON.json(req)); intern_call=true)
    return id["id"]
end

wait_write_session(id::AbstractString) = request("GET", "datasets/wait-write-session/?id=" * id; intern_call=true)

function push_data(id::AbstractString, df::AbstractDataFrame, ds::DSSDataset)
    request("POST", "datasets/push-data/?id=$(id)", Channel(chnl->generator(chnl, df)); intern_call=true)
end

function generator(c::AbstractChannel, df::AbstractDataFrame)
    chunk_size = 5_000_000
    df = convert_dates_to_string(df)
    io = IOBuffer()
    save(CSVFiles.Stream(format"CSV", io), df; nastring="", header=false)
    str = take!(io)
    for i in 1:chunk_size:length(str)
        put!(c, String(str[i:min(end, i+chunk_size-1)]))
    end
end

function write_with_schema(ds::DSSDataset, df::AbstractDataFrame)
    schema = get_schema_from_df(df)
    write_schema(ds, schema)
    id = init_write_session(schema, full_name(ds))
    @async wait_write_session(id)
    push_data(id, df, ds)
end

###################################################
#
#   UTILITY FUNCTIONS
#
###################################################

function get_column_types(schema::AbstractArray, columns::AbstractArray=[])
    types = Dict()
    for column in schema
        if isempty(columns) || Symbol(column["name"]) in columns
            types[column["name"]] = get(DKU_DF_TYPE_MAP, column["type"], String)
        end
    end
    return types
end

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

date_to_string(date) = Dates.format(date, "yyyy-mm-ddTHH:MM:SS.sssZ")

date_to_string(date::Date) = Dates.format(date, "yyyy-mm-dd")

date_to_string(date::Missing) = missing

function convert_dates_to_string(df::AbstractDataFrame)
    for column in names(df)
        if eltype(df[column]) <: TimeType
            df[column] = map(date_to_string, df[column])
        end
    end
    return df
end


function type_to_string(coltype)
    for (name, typename) in DKU_DF_TYPE_MAP
        if typename <: coltype
            return name
        end
    end
    return "string" # default type
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
    return str, "", last_is_quote
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

function create_dataset(name::AbstractString, projectKey=get_projectKey();
        dataset_type="Filesystem",
        connection="filesystem_managed",
        formatType="csv",
        style="excel")
    body = Dict(
        "projectKey"   => projectKey,
        "name"         => name,
        "type"         => dataset_type,
        "formatType"   => formatType,
        "params"       => Dict(
            "connection" => connection,
            "path"       => projectKey * "/" * name
        ),
        "formatParams" => Dict(
            "style"      => style,
            "separator"  => "\t"
        )
    )
    request("POST", "projects/$(projectKey)/datasets/", body)
    return DSSDataset(name, projectKey)
end

function create_dataset(body::AbstractDict, projectKey=get_projectKey())
    request("POST", "projects/$(projectKey)/datasets/", body)
    return DSSDataset(body["name"], projectKey)
end

function delete(ds::DSSDataset; dropData::Bool=false)
    request("DELETE", "projects/$(ds.projectKey)/datasets/$(ds.name)"; params=Dict("dropData" => dropData))
end

# PYTHON API FUNCTIONS

# function get_location_info(ds::DSSDataset; sensitive_info=false)
#     data = Dict(
#         "projectKey"    => ds.projectKey,
#         "datasetName"   => ds.name,
#         "sensitiveInfo" => sensitive_info
#     )
#     post_json("$(intern_url)/datasets/get-location-info/", data)
# end

# function get_files_info(ds::DSSDataset; partitions=[])
#     data = Dict(
#         "projectKey"  => ds.projectKey,
#         "datasetName" => ds.name,
#         "partitions"  => JSON.json(partitions)
#     )
#     post_json("$(intern_url)/datasets/get-files-info/", data)
# end


###################################################################################

"""
    function list_datasets(projectKey=get_projectKey(); foreign=false, tags::AbstractArray=[])
"""
function list_datasets(projectKey=get_projectKey(); kwargs...)
    request("GET", "projects/$(projectKey)/datasets/"; params=kwargs)
end

get_settings(ds::DSSDataset) = request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)")

set_settings(ds::DSSDataset, body::AbstractDict) = request("PUT", "projects/$(ds.projectKey)/datasets/$(ds.name)", body)


get_metadata(ds::DSSDataset) = request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/metadata")

set_metadata(ds::DSSDataset, body::AbstractDict) = request("PUT", "projects/$(ds.projectKey)/datasets/$(ds.name)/metadata", body)


get_schema(ds::DSSDataset) = request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/schema")

set_schema(ds::DSSDataset, body::AbstractDict) = request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/schema", body)


list_partitions(ds::DSSDataset) = request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/partitions")


function get_data(ds::DSSDataset; stream::Bool=false, kw...)
    request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/data"; params=Dict(kw), parse_json=!haskey(kw, :format), stream=stream)
end

function clear_data(ds::DSSDataset, partitions::AbstractArray=[])
    request("DELETE", "projects/$(ds.projectKey)/datasets/$(ds.name)/data"; params=Dict("partitions" => partitions))
end

function get_last_metric_values(ds::DSSDataset, partition::AbstractString="NP")
    request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/metrics/last/$(partition)")
end

function get_single_metric_history(ds::DSSDataset, metricLookup::AbstractString, partition::AbstractString="NP")
    request("GET", "projects/$(ds.projectKey)/datasets/$(ds.name)/metrics/history/$(partition)?metricLookup=$(metricLookup)")
end


list_meanings() = request("GET", "meanings/")

get_meaning_definition(meaningId::AbstractString) = request("GET", "meanings/$(meaningId)")

update_meaning_definition(definition::AbstractDict, meaningId::AbstractString) = request("PUT", "meanings/$(meaningId)", definition)

create_meaning(data::AbstractDict) = request("POST", "meanings/", data)



list_api_services(projectKey=get_projectKey()) = request("GET", "projects/$(projectKey)/apiservices/")

function list_packages(serviceId::AbstractString, projectKey=get_projectKey())
    request("GET", "projects/$(projectKey)/apiservices/$(serviceId)/packages/")
end

function delete_package(serviceId::AbstractString, packageId::AbstractString, projectKey=get_projectKey())
    request("DELETE", "projects/$(projectKey)/apiservices/$(serviceId)/packages/$(packageId)")
end

function download_package_archive(serviceId::AbstractString, packageId::AbstractString, projectKey=get_projectKey())
    request("GET", "projects/$(projectKey)/apiservices/$(serviceId)/packages/$(packageId)/archive"; parse_json=false)
end


get_wiki(projectKey=get_projectKey()) = request("GET", "projects/$(projectKey)/wiki/")

update_wiki(wiki::AbstractDict, projectKey=get_projectKey()) = request("PUT", "projects/$(projectKey)/wiki/", wiki)

get_article(articleId::AbstractString, projectKey=get_projectKey()) = request("GET", "projects/$(projectKey)/wiki/$(articleId)")

update_article(article::AbstractDict, articleId, projectKey=get_projectKey()) = request("PUT", "projects/$(projectKey)/wiki/$(articleId)", article)

function create_article(name::AbstractString, projectKey=get_projectKey(); parent=nothing)
    data = Dict(
        "projectKey" => projectKey,
        "id"         => name
    )
    if parent != nothing data["parent"] = parent end
    request("POST", "projects/$(projectKey)/wiki/", data)
end


function get_discussions(objectId::AbstractString, objectType::AbstractString, projectKey=get_projectKey())
    request("GET", "projects/$(projectKey)/discussions/$(objectType)/$(objectId)/")
end

function get_discussion(objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, projectKey=get_projectKey())
    request("GET", "projects/$(projectKey)/discussions/$(objectType)/$(objectId)/$(discussionId)")
end

function update_discussion(discussion::AbstractDict, objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, projectKey=get_projectKey())
    request("PUT", "projects/$(projectKey)/discussions/$(objectType)/$(objectId)/$(discussionId)", discussion)
end

function create_discussion(objectId::AbstractString, objectType::AbstractString, topic::AbstractString, reply::AbstractString, projectKey=get_projectKey())
    data = Dict(
        "topic" => topic,
        "reply" => reply
    )
    request("POST", "projects/$(projectKey)/discussions/$(objectType)/$(objectId)/", data)
end

function reply(objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, reply::AbstractString, projectKey=get_projectKey())
    request("POST", "projects/$(projectKey)/discussions/$(objectType)/$(objectId)/$(discussionId)/replies/", Dict("reply" => reply))
end


function compute_metrics(ds::DSSDataset, data::AbstractDict; partitions::AbstractArray=[])
    request("POST", "projects/$(ds.projectKey)/datasets/$(ds.name)/actions/computeMetrics/", data; params=Dict(:partitions => partitions))
end

function run_checks(ds::DSSDataset, data::AbstractDict; partitions::AbstractArray=[])
    request("POST", "projects/$(ds.projectKey)/datasets/$(ds.name)/actions/runChecks/"; params=Dict(:partitions => partitions))
end

##################################################################################


# function push_to_git_remote(remote::Union{Nothing, String}, projectKey=get_projectKey())
# 	request("POST", "projects/$(projectKey)/actions/push-to-git-remote", Dict())
# end

# function get_data_alternative_version(ds::DSSDataset)
# 	request("POST", "projects/$(projectKey)/datasets/$(ds.name)/data", Dict())
# end


# function synchronize_hive_metastore(ds::DSSDataset)
# 	request("POST", "projects/$(projectKey)/datasets/$(ds.name)/actions/synchronizeHiveMetastore", Dict())
# end

# function update_from_hive_metastore(ds::DSSDataset)
# 	request("POST", "projects/$(projectKey)/datasets/$(ds.name)/actions/updateFromHive", Dict())
# end


# function generate_package(serviceId::Union{Nothing, String}, packageId::Union{Nothing, String})
# 	request("POST", "projects/$(projectKey)/apiservices/$(serviceId)/packages/$(packageId)", Dict())
# end


##################################################################################

export full_name
export write_schema_from_dataframe

export iter_rows
export iter_tuples
export iter_dataframes

export DSSDataset
export get_dataframe
export get_dataframe_by_row
export get_dataframe_by_chunk

export write_with_schema
export create_dataset
export remove_dataset

export get_schema
export set_schema

export list_partitions