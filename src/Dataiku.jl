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

    using .HttpUtils

    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[end], DSSProject(split(id, '.')[1])) : T(id)

    full_name(object::DSSObject) = object.project.key * "." * (:id in fieldnames(typeof(object)) ? object.id : object.name)
    export full_name

    """
get the global variable FLOW that would be defined if running inside DSS
    """
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

    start_query(data::AbstractString) = request_json("POST", "sql/queries/", data)

    stream_data(queryId::AbstractString; params...) =
        request("GET", "sql/queries/$(queryId)/stream/"; params=params) #TODO understand the way this function streams

    verify_query(queryId::AbstractString) = request("GET", "sql/queries/$(queryId)/finish-streaming")

    list_connections() = request_json("GET", "admin/connections")

    get_connection(connectionName::AbstractString) = request_json("GET", "admin/connections/$(connectionName)")

    update_connection(connection::AbstractDict, connectionName::AbstractString) = request_json("PUT", "admin/connections/$(connectionName)", connection)

    create_connection(body::AbstractDict) = request_json("POST", "admin/connections", body)

    delete_connection(connectionName::AbstractString) = request_json("DELETE", "admin/connections/$(connectionName)")


    list_users(connected::Bool=false) = request_json("GET", "admin/users/?connected=$(connected)")

    get_user(login::AbstractString) = request_json("GET", "admin/users/$(login)")

    update_user(user::AbstractDict, login::AbstractString) = request_json("PUT", "admin/users/$(login)", user)


    # function create_user(login::AbstractString, displayName::AbstractString, password::AbstractString, groups::Array{String, 1})
    #     data = Dict(
    #         "login" => login,
    #         "displayName" => displayName,
    #         "password" => password,
    #         "groups" => groups
    #     )
    # 	request_json("POST", "admin/users", data)
    # end

    delete_user(login::AbstractString) = request_json("DELETE", "admin/users/$(login)")


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


    list_code_envs() = request_json("GET", "admin/code-envs/")

    get_code_env(envName::AbstractString, envLang::AbstractString) =
        request_json("GET", "admin/code-envs/$(envLang)/$(envName)")

    update_code_env(codeEnv::AbstractDict, envName::AbstractString, envLang::AbstractString) =
        request_json("PUT", "admin/code-envs/$(envLang)/$(envName)", codeEnv)

    create_code_env(envName::AbstractString, envLang::AbstractString, data::AbstractDict=Dict()) =
        request_json("POST", "admin/code-envs/$(envLang)/$(envName)", data)

    delete_code_env(envName::AbstractString, envLang::AbstractString) =
        request_json("DELETE", "admin/code-envs/$(envLang)/$(envName)")


    update_code_env_packaged(envName::AbstractString, envLang::AbstractString) =
        request_json("POST", "admin/code-envs/$(envLang)/$(envName)/packages")

    update_jupyter_integration(envName::AbstractString, envLang::AbstractString, active::Bool) =
        request_json("POST", "admin/code-envs/$(envLang)/$(envName)/jupyter?active=$(active)")


    get_general_settings() = request_json("GET", "admin/general-settings")

    update_general_settings(settings::AbstractDict) = request_json("PUT", "admin/general-settings", settings)

    list_logs() = request_json("GET", "admin/logs")

    get_log_content(name::AbstractString) = request_json("GET", "admin/logs/$(name)")


    list_custom_variables() = request_json("GET", "admin/variables")
    set_custom_variables(variables::AbstractDict) = request_json("PUT", "admin/variables", variables)


    get_flow_variable(name::AbstractString) = JSON.parse(ENV["DKUFLOW_VARIABLES"])[name]

    list_flow_variables(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/variables")
    set_flow_variables(variables::AbstractDict, project::DSSProject=get_current_project()) = request_json("PUT", "projects/$(project.key)/variables", variables)

    function list_internal_metrics(; name=nothing, metric_type=nothing)
        params = Dict()
        if name != nothing params["name"] = name end
        if metric_type != nothing params["metric_type"] = metric_type end
        request_json("GET", "internal-metrics"; params=params)
    end
    list_tasks_in_progress(;allUsers=true, withScenarios=true) = request_json("GET", "futures/?allUsers=$allUsers&withScenarios=$withScenarios")

    get_running_task_status(jobId::AbstractString, peek::Bool=false) = request_json("GET", "futures/$jobId?peek=$peek")

    abort_task(jobId::AbstractString) = request_json("GET", "futures/$jobId")

end