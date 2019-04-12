module Dataiku

    abstract type DSSObject end

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

    using .HttpUtils

    export get_dataframe
    export write_with_schema

    export full_name
    export get_definition
    export set_definition
    export get_settings
    export set_settings
    export get_metadata
    export set_metadata
    export create
    export delete

    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[end], DSSProject(split(id, '.')[1])) : T(id)

    full_name(object::DSSObject) = object.project.key * "." * (:id in fieldnames(typeof(object)) ? object.id : object.name)

    """
get the global variable FLOW that would be defined if running inside DSS
    """
    function get_flow()
        if isdefined(Main, :FLOW)
            show(Main.FLOW)
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
            throw(ArgumentError("No projectKey found, initialize project with set_project(::DSSProject)"))
        end
        DSSProject(ENV["DKU_CURRENT_PROJECT_KEY"])
    end

    set_current_project(project::DSSProject) = ENV["DKU_CURRENT_PROJECT_KEY"] = project.key

    start_query(data::AbstractString) = request("POST", "sql/queries/", data)

    stream_data(queryId::AbstractString; params...) =
        request("GET", "sql/queries/$(queryId)/stream/"; params=params, parse_json=haskey(params, "format"))

    verify_query(queryId::AbstractString) = request("GET", "sql/queries/$(queryId)/finish-streaming"; parse_json=false)

    list_connections() = request("GET", "admin/connections")

    get_connection(connectionName::AbstractString) = request("GET", "admin/connections/$(connectionName)")

    update_connection(connection::AbstractDict, connectionName::AbstractString) = request("PUT", "admin/connections/$(connectionName)", connection)

    create_connection(body::AbstractDict) = request("POST", "admin/connections", body)

    delete_connection(connectionName::AbstractString) = request("DELETE", "admin/connections/$(connectionName)")


    list_users(connected::Bool=false) = request("GET", "admin/users/?connected=$(connected)")

    get_user(login::AbstractString) = request("GET", "admin/users/$(login)")

    update_user(user::AbstractDict, login::AbstractString) = request("PUT", "admin/users/$(login)", user)


    # function create_user(login::AbstractString, displayName::AbstractString, password::AbstractString, groups::Array{String, 1})
    #     data = Dict(
    #         "login" => login,
    #         "displayName" => displayName,
    #         "password" => password,
    #         "groups" => groups
    #     )
    # 	request("POST", "admin/users", data)
    # end

    delete_user(login::AbstractString) = request("DELETE", "admin/users/$(login)")


    list_groups() = request("GET", "admin/groups")

    get_group(groupName::AbstractString) = request("GET", "admin/groups/$(groupName)")

    update_group(group::AbstractDict, groupName::AbstractString) = request("PUT", "admin/groups/$(groupName)", group)

    function create_group(name::AbstractString, description::AbstractString="", admin::Bool=false)
        data = Dict(
            "name"        => name,
            "description" => description,
            "admin"       => admin
        )
        request("POST", "admin/groups", data)
    end

    create_group(data::AbstractDict) = request("POST", "admin/groups", data)

    delete_group(groupName::AbstractString) = request("DELETE", "admin/groups/$(groupName)")


    list_code_envs() = request("GET", "admin/code-envs/")

    get_code_env(envName::AbstractString, envLang::AbstractString) =
        request("GET", "admin/code-envs/$(envLang)/$(envName)")

    update_code_env(codeEnv::AbstractDict, envName::AbstractString, envLang::AbstractString) =
        request("PUT", "admin/code-envs/$(envLang)/$(envName)", codeEnv)

    create_code_env(envName::AbstractString, envLang::AbstractString, data::AbstractDict=Dict()) =
        request("POST", "admin/code-envs/$(envLang)/$(envName)", data)

    delete_code_env(envName::AbstractString, envLang::AbstractString) =
        request("DELETE", "admin/code-envs/$(envLang)/$(envName)")


    update_code_env_packaged(envName::AbstractString, envLang::AbstractString) =
        request("POST", "admin/code-envs/$(envLang)/$(envName)/packages")

    update_jupyter_integration(envName::AbstractString, envLang::AbstractString, active::Bool) =
        request("POST", "admin/code-envs/$(envLang)/$(envName)/jupyter?active=$(active)")


    get_general_settings() = request("GET", "admin/general-settings")

    update_general_settings(settings::AbstractDict) = request("PUT", "admin/general-settings", settings)

    list_logs() = request("GET", "admin/logs")

    get_log_content(name::AbstractString) = request("GET", "admin/logs/$(name)")


    list_custom_variables() = request("GET", "admin/variables")
    set_custom_variables(variables::AbstractDict) = request("PUT", "admin/variables", variables)

    list_flow_variables(project::DSSProject=get_current_project()) = request("GET", "projects/$(project.key)/variables")
    set_flow_variables(variables::AbstractDict, project::DSSProject=get_current_project()) = request("PUT", "projects/$(project.key)/variables", variables)

    function list_internal_metrics(; name=nothing, metric_type=nothing)
        params = Dict()
        if name != nothing params["name"] = name end
        if metric_type != nothing params["metric_type"] = metric_type end
        request("GET", "internal-metrics"; params=params)
    end
    list_tasks_in_progress(;allUsers=true, withScenarios=true) = request("GET", "futures/?allUsers=$allUsers&withScenarios=$withScenarios")

    get_running_task_status(jobId::AbstractString, peek::Bool=false) = request("GET", "futures/$jobId?peek=$peek")

    abort_task(jobId::AbstractString) = request("GET", "futures/$jobId")

end