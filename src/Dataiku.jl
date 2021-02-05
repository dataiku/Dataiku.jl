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
    include("variables.jl")
    include("Datasets.jl")
    include("Models.jl")
    include("Folders.jl")

    _type_as_string(obj::T) where {T <: DSSObject} = _type_as_string(T)
    _type_as_string(::Type{DSSDataset}) = "dataset"
    _type_as_string(::Type{DSSFolder}) = "folder"
    _type_as_string(::Type{DSSProject}) = "project"

    _type_as_string(::Type{DSSAnalysis}) = "analysis"
    _type_as_string(::Type{DSSMLTask}) = "mltask"
    _type_as_string(::Type{DSSTrainedModel}) = "trainedmodel"
    _type_as_string(::Type{DSSSavedModel}) = "model"
    _type_as_string(::Type{DSSModelVersion}) = "modelversion"

    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[end], DSSProject(split(id, '.')[1])) : T(id)

    get_name_or_id(object::DSSObject) = :id in fieldnames(typeof(object)) ? object.id : object.name

    function full_name(object::DSSObject)
      project = :project in fieldnames(typeof(object)) ? object.project : get_project(object)
      return project.key * "." * get_name_or_id(object)
    end

    full_name(project::DSSProject) = project.key
    export full_name
end