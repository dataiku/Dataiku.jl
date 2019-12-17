module Dataiku

    abstract type DSSObject end
    export DSSObject

    using JSON

    include("HttpUtils.jl")
    include("Projects.jl")
    include("Datasets.jl")
    include("Recipes.jl")
    include("Jobs.jl")
    include("Scenarios.jl")
    include("Models.jl")
    include("Folders.jl")
    include("Macros.jl")
    include("Bundles.jl")
    include("Plugins.jl")
    include("Discussions.jl")

    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[end], DSSProject(split(id, '.')[1])) : T(id)

    get_project(object) = nothing
    get_project(object::DSSProject) = object
    function get_project(object::DSSObject)
        for field in fieldnames(typeof(object))
            project = get_project(getproperty(object, field))
            if project != nothing
                return project
            end
        end
    end

    get_name_or_id(object::DSSObject) = :id in fieldnames(typeof(object)) ? object.id : object.name

    full_name(object::DSSObject) = object.project.key * "." * get_name_or_id(object)
    export full_name

    # TODO : non-exported functions can't be found with `methodswith(::Types)`

    """
get the global variable FLOW that would be defined if running inside DSS
    """

    # TODO : find a way to give flow variable from the backend here

    function get_flow()
        if isdefined(Main, :FLOW)
            Main.FLOW
        end
    end

    runs_remotely() = isdefined(Main, :DKU_ENV) ? Main.DKU_ENV["runsRemotely"] : true

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
            throw(ArgumentError("No projectKey found, initialize project with Dataiku.set_current_project(::DSSProject)"))
        end
        DSSProject(ENV["DKU_CURRENT_PROJECT_KEY"])
    end

    set_current_project(project::DSSProject) = ENV["DKU_CURRENT_PROJECT_KEY"] = project.key

    list_connections() = request_json("GET", "admin/connections")
    get_connection(connectionName::AbstractString) = request_json("GET", "admin/connections/$(connectionName)")
    update_connection(connection::AbstractDict, connectionName::AbstractString) = request_json("PUT", "admin/connections/$(connectionName)", connection)
    create_connection(body::AbstractDict) = request_json("POST", "admin/connections", body)
    delete_connection(connectionName::AbstractString) = request_json("DELETE", "admin/connections/$(connectionName)")

    list_users(connected::Bool=false) = request_json("GET", "admin/users/?connected=$(connected)")
    get_user(login::AbstractString) = request_json("GET", "admin/users/$(login)")
    update_user(user::AbstractDict, login::AbstractString) = request_json("PUT", "admin/users/$(login)", user)

    list_groups() = request_json("GET", "admin/groups")
    get_group(groupName::AbstractString) = request_json("GET", "admin/groups/$(groupName)")
    update_group(group::AbstractDict, groupName::AbstractString) = request_json("PUT", "admin/groups/$(groupName)", group)
    function create_group(name::AbstractString, description::AbstractString="", admin::Bool=false)
        data = Dict(
            "name"        => name,
            "description" => description,
            "admin"       => admin
        )
        request_json("POST", "admin/groups", data)
    end

    create_group(data::AbstractDict) = request_json("POST", "admin/groups", data)
    delete_group(groupName::AbstractString) = request_json("DELETE", "admin/groups/$(groupName)")

    get_general_settings() = request_json("GET", "admin/general-settings")
    update_general_settings(settings::AbstractDict) = request_json("PUT", "admin/general-settings", settings)

    list_logs() = request_json("GET", "admin/logs")
    get_log_content(name::AbstractString) = request_json("GET", "admin/logs/$(name)")

    list_custom_variables() = request_json("GET", "admin/variables")
    set_custom_variables(variables::AbstractDict) = request_json("PUT", "admin/variables", variables)


    get_flow_variable(name::AbstractString) = JSON.parse(ENV["DKUFLOW_VARIABLES"])[name]

    list_flow_variables(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/variables")
    set_flow_variables(variables::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/variables", variables)

    list_internal_metrics(; params...) = request_json("GET", "internal-metrics"; params=params) # kwargs : name, metric_type

    list_tasks_in_progress(;allUsers=true, withScenarios=true) = request_json("GET", "futures/?allUsers=$allUsers&withScenarios=$withScenarios")

    get_running_task_status(jobId::AbstractString, peek::Bool=false) = request_json("GET", "futures/$jobId?peek=$peek")
    abort_task(jobId::AbstractString) = request_json("GET", "futures/$jobId")

    list_meanings() = request_json("GET", "meanings/")
    get_meaning_definition(meaningId::AbstractString) = request_json("GET", "meanings/$(meaningId)")
    update_meaning_definition(definition::AbstractDict, meaningId::AbstractString) = request_json("PUT", "meanings/$(meaningId)", definition)
    create_meaning(data::AbstractDict) = request_json("POST", "meanings/", data)

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

end
