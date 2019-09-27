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

also see `iter_dataframes`

"""
function get_dataframe(ds::DSSDataset, columns::AbstractArray=[]; infer_types=true, kwargs...)
    names, types = _get_reading_schema(ds, columns; infer_types=infer_types)
    stream = get_stream("projects/$(ds.project.key)/datasets/$(ds.name)/data"; params=_get_reading_params(ds; kwargs...))
    load(CSVFiles.Stream(format"TSV", stream); header_exists=false, colnames=names, colparsers=types) |> DataFrame
end

function _get_reading_schema(ds::DSSDataset, columns::AbstractArray=[]; infer_types=true)
    schema = get_schema(ds)["columns"]
    get_column_names(schema, columns), infer_types ? [] : get_column_types(schema, columns)
end

function _get_reading_params(ds::DSSDataset; partitions=nothing, kwargs...)
    if !(partitions!=nothing && !isempty(partitions)) && !runs_remotely()
        partitions = get(get_flow_inputs(ds), "partitions", "")
    end
    Dict(
        "sampling"   => JSON.json(_create_sampling_argument(; kwargs...)),
        "format"     => "tsv-excel-noheader",
        "partitions" => partitions
    )
end

function iter_data_chunks(ds::DSSDataset, columns::AbstractArray=[]; infer_types=true, kwargs...)
    names, types = _get_reading_schema(ds, columns; infer_types=infer_types)
    Channel(;ctype=DataFrame) do chnl
        first_line = ""
        open_quotes = false
        for data in get_chnl("projects/$(ds.project.key)/datasets/$(ds.name)/data"; params=_get_reading_params(ds; kwargs...))
            chunk, last_line, open_quotes = _split_last_line(String(data), open_quotes)
            df = load(CSVFiles.Stream(format"TSV", IOBuffer(first_line * chunk)); header_exists=false, colnames=names, colparsers=types) |> DataFrame
            first_line = last_line
            put!(chnl, df)
        end
    end
end

# remove the last incomplete line of the chunk, keep the last line in memory to add it to the next chunk
function _split_last_line(str::AbstractString, open_quotes::Bool=false, quotechar='\"')
    inquote = open_quotes = count(i -> (i == quotechar), str) % 2 == 1 ⊻ open_quotes # Check if the end of the string is inquote
    for i in Iterators.reverse(eachindex(str))
        if !inquote && str[i] == '\n'
            return str[1:i], str[nextind(str, i):end], open_quotes
        elseif str[i] == quotechar
            inquote = !inquote
        end
    end
    str, "", open_quotes
end

function iter_rows(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
    Channel(;ctype=DataFrameRow) do chnl
        for chunk in iter_data_chunks(ds, columns; kwargs...)
            for row in eachrow(chunk)
                put!(chnl, row)
            end
        end
    end
end

"""
```julia
function iter_dataframes(ds::DSSDataset, nrows::Integer=10_000, columns::AbstractArray=[]; kwargs...)
```
Returns  an iterator over the data of a dataframe. Can be used to access data without loading the full dataset in memory.
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
### example
```julia
for chunk in Dataiku.iter_dataframes(dataset"example", 500)
    # iterate through chunks of 500 rows.
end
```
"""
function iter_dataframes(ds::DSSDataset, n::Integer=10_000, columns::AbstractArray=[]; kwargs...)
    Channel(;ctype=DataFrame) do chnl
        chunks = iter_data_chunks(ds, columns; kwargs...)
        df = DataFrame()
        for chunk in chunks
            df = vcat(df, chunk)
            for i in n:n:nrow(df)
                put!(chnl, df[1:n, :])
                df = df[n+1:end, :]
            end
        end
        put!(chnl, df)
    end
end

function iter_tuples(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
    Channel(;ctype=Tuple) do chnl
        for chunk in iter_data_chunks(ds, columns; kwargs...)
            for row in 1:nrow(chunk)
                put!(chnl, Tuple(chunk[row,col] for col in 1:ncol(chunk)))
            end
        end
    end
end

###################################################
#
#   WRITING FUNCTIONS
#
###################################################

# """
# Write a function to an already existing (but maybe empty) Dataset, update the schema of the dataset
# ```julia
# write_with_schema(f::Function, ds::DSSDataset; kwargs...)
# ```
# ### Keywords parameters
# - `partition::AbstractString` : specify the partition to write.
# - `overwrite::Bool=true` : if `false`, appends the data to the already existing dataset.
# example :
# ```julia
# Dataiku.write_with_schema(dataset"input_dataset") do chnl
#     for chunk in Dataiku.iter_data_chunks(dataset"output_dataset")
#         put!(chnl, chunk)
#     end
# end
# ```
# """
# write_with_schema(f::Function, ds::DSSDataset; kwargs...) =
#     write_with_schema(ds, dataframe_chnl_to_csv(Channel(f; ctype=AbstractDataFrame))...)

"""
Writes this dataset (or its target partition) from a single DataFrame.
```julia
write_with_schema(ds::DSSDataset, df::AbstractDataFrame; kwargs...)
```
This variant replaces the schema of the output dataset with the schema
of the dataframe.

### Keywords parameters
- `partition::AbstractString` : specify the partition to write.
- `overwrite::Bool=true` : if `false`, appends the data to the already existing dataset.
"""
write_with_schema(ds::DSSDataset, df::AbstractDataFrame; kwargs...) =
    write_dataframe(ds, df; infer_schema=true, kwargs...)
    
"""
```julia
write_dataframe(ds::DSSDataset, df::AbstractDataFrame; infer_schema=false, kwargs...)
```
Writes this dataset (or its target partition) from a single DataFrame.

This variant only edit the schema if infer_schema is True, otherwise you must
take care to only write dataframes that have a compatible schema.

Also see "write_with_schema".

### Keywords parameters
- `partition::AbstractString` : specify the partition to write.
- `overwrite::Bool=true` : if `false`, appends the data to the already existing dataset.
"""
function write_dataframe(ds::DSSDataset, df::AbstractDataFrame; infer_schema=false, kwargs...)
    schema = get_schema_from_df(df)
    if infer_schema
        set_schema(ds, schema)
    end
    write_data(ds, _get_stream_write(df), schema; kwargs...)
end

function write_dataframe(f::Function, ds::DSSDataset; kwargs...)
    chnl = Channel(f; ctype=AbstractDataFrame)
    write_data(ds, _dataframe_chnl_to_csv(chnl), _get_schema_from_chnl(chnl))
end

function _dataframe_chnl_to_csv(chnl::Channel{AbstractDataFrame})
    df = DataFrame()
    Channel() do output
        for df in chnl
            put!(output, _get_stream_write(df))
        end
    end
end

function _get_schema_from_chnl(chnl::Channel) # take the first chunk of the dataframe, get the schema out of it then put it back
    first_chunk = take!(chnl)
    @async put!(chnl, first_chunk)
    get_schema_from_df(first_chunk)
end

function write_data(ds, data, schema; kwargs...)
    id = _init_write_session(ds, schema; kwargs...)
    task = @async _wait_write_session(id)
    _push_data(id, data)
end

function _init_write_session(ds::DSSDataset, schema::AbstractDict; method="STREAM", partition="", overwrite=true)
    req = Dict(
        "method"          => method,
        "partitionSpec"   => (partition == "" && !runs_remotely()) ? get(get_flow_outputs(ds), "partition", "") : partition,
        "fullDatasetName" => full_name(ds),
        "writeMode"       => overwrite ? "OVERWRITE" : "APPEND",
        "dataSchema"      => schema
        )
        request_json("POST", "datasets/init-write-session/", Dict("request" => JSON.json(req)); intern_call=true)["id"]
    end
    
    function _wait_write_session(id::AbstractString)
        res = request_json("GET", "datasets/wait-write-session/?id=" * id; intern_call=true)
        if res["ok"]
            @info "$(res["writtenRows"]) rows successfully written ($id)"
        else
            error("An error occurred during dataset write ($id): $(res["message"])")
        end
    end
    
    _push_data(id::AbstractString, data) = request("POST", "datasets/push-data/?id=$(id)", data; intern_call=true)
    
    function _get_stream_write(df::AbstractDataFrame)
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
    
    get_flow_outputs(ds::DSSDataset) = _get_flow_inputs_or_outputs(ds, "out")
    
    get_flow_inputs(ds::DSSDataset) = _get_flow_inputs_or_outputs(ds, "in")
    
    function _get_flow_inputs_or_outputs(ds::DSSDataset, option)
        puts = find_field(get_flow()[option], "fullName", full_name(ds))
        if puts == nothing
            throw(ArgumentError("Dataset isn't an " * option * "put of the recipe"))
        end
        puts
    end
    
    get_column_types(ds::DSSDataset, columns::AbstractArray=[]) = get_column_types(get_schema(ds)["columns"], columns)
    get_column_types(schema::AbstractArray, cols::AbstractArray=[]) =
    [col["name"] => _string_to_type(col["type"]) for col in schema if isempty(cols) || Symbol(col["name"]) in cols] |> Dict
    
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

_string_to_type(str) = get(DKU_DF_TYPE_MAP, str, String)

function _type_to_string(coltype)
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

function get_schema_from_df(df::AbstractDataFrame)
    new_columns = Any[]
    for name in names(df)
        new_column = Dict("name" => String(name),
                          "type" => _type_to_string(eltype(df[!, name])))
        push!(new_columns, new_column)
    end
    Dict("columns" => new_columns, "userModified" => false)
end

function _create_sampling_argument(; sampling::String="head", sampling_column=nothing, limit=nothing, ratio=nothing)
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
        "managed"      => true,
        "params"       => Dict(
            "connection" => connection,
            "path"       => project.key * "/" * name
        ),
        "formatParams" => Dict(
            "style"      => style,
            "separator"  => "\t"
        ),
        )
    create_dataset(body, project)
end

function create_dataset(body::AbstractDict, project::DSSProject=get_current_project())
    request_json("POST", "projects/$(project.key)/datasets/", body)
    DSSDataset(body["name"], project)
end

delete(ds::DSSDataset; dropData::Bool=false) = request_json("DELETE", "projects/$(ds.project.key)/datasets/$(ds.name)"; params=Dict("dropData" => dropData))

# RECURSIVE_BUILD, NON_RECURSIVE_FORCED_BUILD, RECURSIVE_FORCED_BUILD, RECURSIVE_MISSING_ONLY_BUILD
function build(ds::DSSDataset; partitions=nothing, job_type::AbstractString="RECURSIVE_FORCED_BUILD")
    body = Dict(
        "outputs" => [Dict(
            "projectKey" => ds.project.key,
            "id"         => ds.name
            )],
        "type" => job_type
    )
    if partitions != nothing body["outputs"][1]["partition"] = partitions end
    start_job(body, ds.project)
end

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

        
function compute_metrics(ds::DSSDataset; partition::AbstractString="", metrics_ids=nothing, probes=[])
    body = metrics_ids != nothing ? Dict("metricIds" => metrics_ids) : probes
    request_json("POST", "projects/$(ds.project.key)/datasets/$(ds.name)/actions/computeMetrics/", body; params=Dict(:partition => partitions))
end

run_checks(ds::DSSDataset, checks=[]; partition::AbstractString="") =
    request_json("POST", "projects/$(ds.project.key)/datasets/$(ds.name)/actions/runChecks/", checks; params=Dict(:partition => partitions))