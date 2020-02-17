module Dataiku

    abstract type DSSObject end
    export DSSObject

    using JSON

    struct DkuException<: Exception
		msg::String
    end
    Base.showerror(io::IO, e::DkuException) = print(io, "DkuException: " * e.msg)

    include("request.jl")
    include("Projects.jl")
    include("Datasets.jl")
    include("Models.jl")
    include("Folders.jl")

    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[end], DSSProject(split(id, '.')[1])) : T(id)

    get_project(object) = nothing
    get_project(object::DSSProject) = object
    function get_project(object::DSSObject)
        for field in fieldnames(typeof(object))
            project = get_project(getproperty(object, field))
            if !isnothing(project)
                return project
            end
        end
    end

    get_name_or_id(object::DSSObject) = :id in fieldnames(typeof(object)) ? object.id : object.name

    full_name(object::DSSObject) = object.project.key * "." * get_name_or_id(object)
    export full_name

    function get_flow()
        if _is_inside_recipe()
            return JSON.parse(ENV["DKUFLOW_SPEC"])
        end
        throw(DkuException("Env variable 'DKUFLOW_SPEC' not defined."))
    end

    _is_inside_recipe() = haskey(ENV, "DKUFLOW_SPEC")

    """
```julia
find_field(list::AbstractArray, field::AbstractString, value)
```
look for a dict that has this `value` at this `field` in an array of dict
    """
    function find_field(dict::AbstractArray, field::AbstractString, value)
        for item in dict
            if value == item[field]
                return item
            end
        end
    end

    function get_current_project()
        if !haskey(ENV, "DKU_CURRENT_PROJECT_KEY")
            if isinteractive()
                println("No projectKey found, define current project with Dataiku.set_current_project(::DSSProject)")
                set_current_project()
            else
                throw(DkuException("No projectKey found, define current project with Dataiku.set_current_project(::DSSProject)"))
            end
        end
        DSSProject(ENV["DKU_CURRENT_PROJECT_KEY"])
    end

    function set_current_project()
        if !isinteractive()
            throw(DkuException("Cannot interactively define project key."))
        end
        while true
            println("Existing projects:")
            for project in list_projects()
                println(project["projectKey"])
            end
            print("enter projectKey (empty for aborting): ")
            project = DSSProject(readline(stdin))
            if isempty(project.key)
                throw(DkuException("No projectKey found, define current project with Dataiku.set_current_project(::DSSProject)"))
            elseif exists(project)
                return set_current_project(project)
            else
                println("Project \'$(project.key)\' doesn't exist or you don't have permissions to access it.")
            end
        end
    end
    
    function set_current_project(project::DSSProject)
        if exists(project)
            ENV["DKU_CURRENT_PROJECT_KEY"] = project.key
            @info "Current project set to \'$(project.key)\'"
        else
            throw(DkuException("Project \'$(project.key)\' doesn't exist or you don't have permissions to access it."))
        end
    end

    function get_custom_variables(resolved=true, project::DSSProject=get_current_project())
        if haskey(ENV, "DKU_CUSTOM_VARIABLES")
            return JSON.parse(ENV["DKU_CUSTOM_VARIABLES"])
        else
            request_json("GET", "projects/$(project.key)/variables"*(resolved ? "-resolved" : ""))
        end
    end

    function get_flow_variable(name::AbstractString)
        if _is_inside_recipe()
            JSON.parse(ENV["DKUFLOW_VARIABLES"])[name]
        else
            throw(DkuException("Cannot get flow variables outside of a recipe"))
        end
    end
end
