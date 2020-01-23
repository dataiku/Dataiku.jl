	using JSON
	using HTTP
	using Base64
	using BufferedStreams

	struct DSSContext
		url::AbstractString
		auth::AbstractString
	end

	context = nothing

"""
```julia
init_context()
init_context(url::AbstractString, authentication::AbstractString)
```
If no argument given, will try to find url and authentication from (in this order)
1 - tickets environment variables (`DKU_BACKEND_HOST`, `DKU_NGINX_PORT` and `DKU_API_TICKET`)
2 - api key and url environment variable (`DKU_DSS_URL` and `DKU_API_KEY`)
3 - `\$HOME/.dataiku/config.json`
"""
	init_context(url::AbstractString, auth::AbstractString) = global context = DSSContext(url, auth)

	function init_context()
		if haskey(ENV, "DKU_API_TICKET")
			global context = DSSContext(
				"http://$(get(ENV, "DKU_BACKEND_HOST", "127.0.0.1")):$(ENV["DKU_NGINX_PORT"])/",
				ENV["DKU_API_TICKET"]
			)
		elseif haskey(ENV, "DKU_DSS_URL") && haskey(ENV, "DKU_API_KEY")
			global context = DSSContext(
				ENV["DKU_DSS_URL"],
				ENV["DKU_API_KEY"]
			)
		elseif isfile("$(ENV["HOME"])/.dataiku/config.json")
			config = JSON.parsefile("$(ENV["HOME"])/.dataiku/config.json")
			global context = DSSContext(
				config["dss_instances"][config["default_instance"]]["url"],
				config["dss_instances"][config["default_instance"]]["api_key"]
			)
		else
			throw(ErrorException("No context found, please initialize context by giving url and authentication parameters"))
		end
		context
	end

	get_context() = isnothing(context) ? init_context() : context

	function get_auth_header()
		if haskey(ENV, "DKU_API_TICKET")
			Dict("X-DKU-APITicket" => ENV["DKU_API_TICKET"])
		else
			Dict("Authorization" => "Basic $(base64encode(get_context().auth * ":"))")
		end
	end

	addparam(param, value::Any) = "$param=$value"
	addparam(param, value::AbstractArray) = addparam(param, join(value, ','))
	
	function querystring(params::AbstractDict)
		list_params = [addparam(param, value) for (param, value) in params if !isnothing(value) && !isempty(value)]
		isempty(list_params) ? "" : "?" * join(list_params, '&')
	end
	querystring(params::Nothing) = ""
	

	function get_url_and_header(url; intern_call=false, params=nothing, verbose=false)
		header = get_auth_header()
		header["Content-Type"] = "application/" * (intern_call ? "x-www-form-urlencoded" : "json")
		url = get_context().url * (intern_call ? "dip/api/tintercom/" : "public/api/") * url * querystring(params)
		verbose && @info url, JSON.json(header)
		url, header
	end

	function request(req, url, body=""; intern_call=false, kwargs...)
		if (typeof(body) <: AbstractDict)
			body = intern_call ? HTTP.URIs.escapeuri(body) : JSON.json(body)
		end
		res = HTTP.request(req, get_url_and_header(url; intern_call=intern_call, kwargs...)..., body).body |> String
		return isempty(res) ? nothing : res
	end

	function request_json(req::AbstractString, url::AbstractString, body=""; kwargs...)
		res = request(req, url, body; kwargs...)
		return isnothing(res) ? res : JSON.parse(res)
	end

	get_stream(f::Function, url; kwargs...) = HTTP.open(f, "GET", get_url_and_header(url; kwargs...)...)

	post_multipart(url::AbstractString, path::AbstractString, filename::AbstractString=basename(path)) =
		post_multipart(url, open(path, read=true), filename)

	function post_multipart(url::AbstractString, file::IO, filename::AbstractString="file")::String
		body = HTTP.Form(Dict("file" => HTTP.Multipart(filename, file)))
		url_request, header = get_url_and_header(url)
		header["Content-Type"] = "multipart/form-data; boundary=$(body.boundary)"
		HTTP.request("POST", url_request, header, body).body |> String
	end