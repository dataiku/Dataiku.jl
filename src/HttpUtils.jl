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
			throw(ArgumentError("No context found, please initialize context by giving url and authentication parameters"))
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
	
	get_url(url::AbstractString, params=nothing, intern_call=false) =
		get_context().url * (intern_call ? "dip/api/tintercom/" : "public/api/") * url * querystring(params)

	function get_url_and_header(url, params=nothing, intern_call=false)
		header = get_auth_header()
		header["Content-Type"] = "application/" * (intern_call ? "x-www-form-urlencoded" : "json")
		get_url(url, params, intern_call), header
	end

	request(req::AbstractString, url::AbstractString, body::AbstractDict; intern_call=false, params=nothing)::String =
		request(req, url, intern_call ? HTTP.URIs.escapeuri(body) : JSON.json(body); intern_call=intern_call, params=params)

	function request(req::AbstractString, url::AbstractString, body=""; intern_call=false, params=nothing)
		res = HTTP.request(req, get_url_and_header(url, params, intern_call)..., body).body
		isempty(res) && return nothing
		String(res)
	end


	request_json(req::AbstractString, url::AbstractString, body::AbstractDict; intern_call=false, params=nothing) =
		request_json(req, url, intern_call ? HTTP.URIs.escapeuri(body) : JSON.json(body); intern_call=intern_call, params=params)

	function request_json(req::AbstractString, url::AbstractString, body=""; intern_call=false, params=nothing)
		res = HTTP.request(req, get_url_and_header(url, params, intern_call)..., body).body |> String
		isempty(res) && return nothing
		JSON.parse(res)
	end

	function get_stream(url::AbstractString; intern_call=false, params=nothing)
		io = Base.BufferStream()
		HTTP.request("GET", get_url_and_header(url, params, intern_call)...; response_stream=io)
		io
	end

	get_chnl(url::AbstractString; kwargs...) = Channel(chnl->_get_chnl(chnl, url; kwargs...))

	function _get_chnl(chnl::AbstractChannel, url::AbstractString; intern_call=false, params=nothing)
		HTTP.open("GET", get_url_and_header(url, params, intern_call)...) do stream
			while !eof(stream)
				put!(chnl, readavailable(stream))
			end
		end
	end

	post_multipart(url::AbstractString, path::AbstractString, filename::AbstractString=basename(path)) =
		post_multipart(url, open(path, read=true), filename)

	function post_multipart(url::AbstractString, file::IO, filename::AbstractString="file")::String
		body = HTTP.Form(Dict("file" => HTTP.Multipart(filename, file)))
		url_request, header = get_url_and_header(url)
		header["Content-Type"] = "multipart/form-data; boundary=$(body.boundary)"
		HTTP.request("POST", url_request, header, body).body |> String
	end

	export init_context
	export post_multipart
	export request_json
	export get_stream
	export get_chnl
	export request
end