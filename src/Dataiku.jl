module Dataiku

"""
`DSSObject`

Abstraction of all DSS objects.

### Children

* `DSSDataset`
* `DSSFolder`
* `DSSProject`
* `DSSSavedModel`
* `DSSTrainedModel`
* `DSSMLTask`
* `DSSAnalysis`
"""
    abstract type DSSObject end
    export DSSObject
    Base.show(io::IO, object::T) where T <: DSSObject = print(io, _type_as_string(T) * "\""* full_name(object) * "\"")

    using JSON

    struct DkuException<: Exception
		msg::String
    end
    Base.showerror(io::IO, e::DkuException) = print(io, "DkuException: " * e.msg)

    include("flow.jl")
    include("request.jl")
    include("Projects.jl")
    include("Datasets.jl")
    include("Models.jl")
    include("Folders.jl")

    _type_as_string(::Type{DSSDataset}) = "dataset"
    _type_as_string(::Type{DSSFolder}) = "folder"
    _type_as_string(::Type{DSSProject}) = "project"

    _type_as_string(::Type{DSSTrainedModel}) = "trainedmodel"
    _type_as_string(::Type{DSSSavedModel}) = "model"

    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[end], DSSProject(split(id, '.')[1])) : T(id)

    get_name_or_id(object::DSSObject) = :id in fieldnames(typeof(object)) ? object.id : object.name

    full_name(object::DSSObject) = object.project.key * "." * get_name_or_id(object)
    export full_name

    function get_custom_variables(resolved=true, project::DSSProject=get_current_project())
        if haskey(ENV, "DKU_CUSTOM_VARIABLES")
            return JSON.parse(ENV["DKU_CUSTOM_VARIABLES"])
        else
            request_json("GET", "projects/$(project.key)/variables"*(resolved ? "-resolved" : ""))
        end
    end
end