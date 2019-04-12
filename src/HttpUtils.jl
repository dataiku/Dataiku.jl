module HttpUtils

	using JSON
	using HTTP
	using Base64

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
3 - `HOME/.dataiku/config.json`
"""
	init_context(url::AbstractString, auth::AbstractString) = global context = DSSContext(url, auth)

	function init_context()
		if haskey(ENV, "DKU_API_TICKET")
			global context = DSSContext(
				"http://$(get(ENV, "DKU_BACKEND_HOST", "127.0.0.1")):$(ENV["DKU_NGINX_PORT"])/", # using nginx port instead of backend_port
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
			throw(ArgumentError("No context found, please initialize context by giving url and authentication parameters"))
		end
		context
	end

	_get_context() = context == nothing ? init_context() : context

	function get_auth_header()
		if haskey(ENV, "DKU_API_TICKET")
			Dict("X-DKU-APITicket" => ENV["DKU_API_TICKET"])
		else
			Dict("Authorization" => "Basic $(base64encode(_get_context().auth * ":"))")
		end
	end
	
	addparam(param, value::Any) = "$param=$value"
	addparam(param, value::AbstractArray) = addparam(param, join(value, ','))
	
	"""
	```julia
	querystring(params::AbstractDict)
	```
	add all the parameters to the url
	"""
	function querystring(params::AbstractDict)
		list_params = [addparam(param, value) for (param, value) in params if !isnothing(value) && !isempty(value)]
		isempty(list_params) ? "" : "?" * join(list_params, '&')
	end
	querystring(params::Nothing) = ""
	
	get_url(url::AbstractString, params::Union{AbstractDict, Nothing}=nothing, intern_call=false) =
	_get_context().url * (intern_call ? "dip/api/tintercom/" : "public/api/") * url * querystring(params)
	
	function request(request::AbstractString, url::AbstractString, body=nothing; intern_call=false,
		params=nothing, parse_json=true, stream=false)
		header = get_auth_header()
		url = get_url(url, params, intern_call)
		header["Content-Type"] = "application/" * (intern_call ? "x-www-form-urlencoded" : "json")
		getbody(_body::Nothing) = UInt8[]
		getbody(_body::AbstractDict) = intern_call ? HTTP.URIs.escapeuri(_body) : JSON.json(_body)
		getbody(_body) = _body # nested methods to handle different body types
		request_body = getbody(body)
		if stream
			io = Base.BufferStream()
			@async HTTP.request(request, url, header, request_body; response_stream=io)
			return io
		else
			response = HTTP.request(request, url, header, request_body)
		end
		data = String(response.body)
		if isempty(data)
			return nothing
		end
		parse_json ? JSON.parse(data) : data
	end

	post_multipart(url::AbstractString, path::AbstractString, filename::AbstractString="file") = post_multipart(url, open(path, read=true), filename)

	function post_multipart(url::AbstractString, file::IO, filename::AbstractString="file")
		body = HTTP.Form(Dict("file" => HTTP.Multipart(filename, file)))
		header = get_auth_header()
		header["Content-Type"] = "multipart/form-data; boundary=$(body.boundary)"
		response = HTTP.request("POST", get_url(url), header, body)
		String(response.body)
	end

	export post_multipart
	export request
end
