module HttpUtils

	using HTTP
	using JSON
	using Base64

	struct DSSContext
		url::AbstractString
		auth::AbstractString
		DSSContext(url::AbstractString, auth::AbstractString) = new(url, auth)
	end

	context = nothing

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
		else
			config = JSON.parsefile("$(ENV["HOME"])/.dataiku/config.json")
			global context = DSSContext(
				config["dss_instances"][config["default_instance"]]["url"],
				config["dss_instances"][config["default_instance"]]["api_key"]
			)
		end
		context
	end

	_get_context() = HttpUtils.context == nothing ? init_context() : context::DSSContext

	function _get_auth_header()
		if haskey(ENV, "DKU_API_TICKET")
			return Dict("X-DKU-APITicket" => ENV["DKU_API_TICKET"])
		else
			return Dict("Authorization" => "Basic $(base64encode(_get_context().auth * ":"))")
		end
	end

	addparam(param, value::Any) = "$param=$value"
	addparam(param, value::AbstractArray) = isempty(value) ? "" : addparam(param, join(value, ','))
	addparam(param, value::Nothing) = ""

	querystring(params::AbstractDict) = isempty(params) ? "" : "?" * join([addparam(param, value) for (param, value) in params], '&')
	querystring(params::Nothing) = ""

	function get_url(url::AbstractString, params::Union{AbstractDict, Nothing}=nothing, intern_call=false)
		_get_context().url * (intern_call ? "dip/api/tintercom/" : "public/api/") * url * querystring(params)
	end

	function request(request::AbstractString, url::AbstractString, body=""; intern_call=false,
			params=nothing, parse_json=true, stream=false)
		header = _get_auth_header()
		url = get_url(url, params, intern_call)
		if request in ("POST", "PUT")
			header["Content-Type"] = "application/" * (intern_call ? "x-www-form-urlencoded" : "json")
			body = typeof(body) <: Dict ? (intern_call ? HTTP.URIs.escapeuri(body) : JSON.json(body)) : body
		else
			body = UInt8[]
		end
		if stream
			io = Base.BufferStream()
			@async HTTP.request(request, url, header, body; response_stream=io)
			return io
		else
			response = HTTP.request(request, url, header, body)
		end
		data = String(response.body)
		return parse_json && !isempty(data) ? JSON.parse(data) : data
	end

	post_multipart(url::AbstractString, path::AbstractString, filename::AbstractString="file") = post_multipart(url, open(path, read=true), filename)

	function post_multipart(url::AbstractString, file::IO, filename::AbstractString="file")
		body = HTTP.Form(Dict("file" => HTTP.Multipart(filename, file)))
		header = _get_auth_header()
		header["Content-Type"] = "multipart/form-data; boundary=$(body.boundary)"
		response = HTTP.request("POST", get_url(url), header, body)
		return String(response.body)
	end

	export post_multipart
	export request
end
