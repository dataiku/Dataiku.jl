module Dataiku

    abstract type DSSObject end

    include("HttpUtils.jl")
    include("Datasets.jl")
    include("Projects.jl")
    include("Recipes.jl")
    include("Jobs.jl")
    include("Scenarios.jl")
    include("Models.jl")
    include("Folders.jl")
    include("Macros.jl")
    include("Bundles.jl")
    include("Plugins.jl")

    using .HttpUtils

    using JSON

    export get_dataframe
    export write_with_schema

    export full_name
    export get_settings
    export set_settings
    export get_metadata
    export set_metadata
    export create
    export delete


    createobject(::Type{T}, id) where {T <: DSSObject} = '.' in id ? T(split(id, '.')[2], split(id, '.')[1]) : T(id)
    full_name(object::DSSObject) = object.projectKey * "." * (:id in fieldnames(typeof(object)) ? object.id : object.name)

    get_projectKey() = ENV["DKU_CURRENT_PROJECT_KEY"]

    start_a_query(data::AbstractString) = request("POST", "sql/queries/", data)

    function stream_the_data(queryId::AbstractString; params...)
        params = Dict()
        if formatParams != nothing params["formatParams"] = formatParams end
        if format != nothing
            params["format"] = format
            request("GET", "sql/queries/$(queryId)/stream/"; params=params, parse_json=false)
        else
            request("GET", "sql/queries/$(queryId)/stream/"; params=params)
        end
    end

    verify_a_query(queryId::AbstractString) = request("GET", "sql/queries/$(queryId)/finish-streaming"; parse_json=false)

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

    get_code_env(envName::AbstractString, envLang::AbstractString) = request("GET", "admin/code-envs/$(envLang)/$(envName)")

    function update_code_env(codeEnv::AbstractDict, envName::AbstractString, envLang::AbstractString)
        request("PUT", "admin/code-envs/$(envLang)/$(envName)", codeEnv)
    end

    function create_code_env(envName::AbstractString, envLang::AbstractString, data::AbstractDict=Dict())
        request("POST", "admin/code-envs/$(envLang)/$(envName)", data)
    end

    function delete_code_env(envName::AbstractString, envLang::AbstractString)
        request("DELETE", "admin/code-envs/$(envLang)/$(envName)")
    end


    function update_code_env_packaged(envName::AbstractString, envLang::AbstractString)
        request("POST", "admin/code-envs/$(envLang)/$(envName)/packages")
    end

    function update_jupyter_integration(envName::AbstractString, envLang::AbstractString, active::Bool)
        request("POST", "admin/code-envs/$(envLang)/$(envName)/jupyter?active=$(active)")
    end


    get_general_settings() = request("GET", "admin/general-settings")

    update_general_settings(settings::AbstractDict) = request("PUT", "admin/general-settings", settings)

    list_logs() = request("GET", "admin/logs")

    get_log_content(name::AbstractString) = request("GET", "admin/logs/$(name)")


    list_variables() = request("GET", "admin/variables")

    save_variables(variables::AbstractDict) = request("PUT", "admin/variables", variables)

    function list_internal_metrics(; name=nothing, metric_type=nothing)
        params = Dict()
        if name != nothing params["name"] = name end
        if metric_type != nothing params["metric_type"] = metric_type end
        request("GET", "internal-metrics"; params=params)
    end

end