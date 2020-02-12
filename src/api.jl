	using JSON
	using HTTP
	using Base64

	struct DSSContext
		url::AbstractString
		auth::AbstractString
	end

	context = nothing

	struct DkuAPIException<: Exception
		function DkuAPIException(e::AbstractDict)
			msg = get(e, "detailedMessage", e["message"])
			type = split(get(e, "errorType", ""), '.') |> last
			new(msg, type)
		end
		DkuAPIException(e::AbstractString) = new(msg, "")
		msg::String
		type::String
	end
	
	Base.showerror(io::IO, e::DkuAPIException) = print(io, "DkuAPIException: " * (isempty(e.type) ? "" : e.type * ": ") * e.msg)

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
			throw(DkuException("No context found, please initialize context by giving url and authentication parameters"))
		end
		context
	end

	get_context() = isnothing(context) ? init_context() : context

	addparam(param, value::Any) = "$param=$value"
	addparam(param, value::AbstractArray) = addparam(param, join(value, ','))
	
	function querystring(params::AbstractDict)
		list_params = [addparam(param, value) for (param, value) in params if !isnothing(value) && !isempty(value)]
		isempty(list_params) ? "" : "?" * join(list_params, '&')
	end
	querystring(params::Nothing) = ""

	function get_url_and_header(url; intern_call=false, content_type="application/"*(intern_call ? "x-www-form-urlencoded" : "json"), params=nothing, verbose=false)
		header = Dict()
		if haskey(ENV, "DKU_API_TICKET")
			header["X-DKU-APITicket"] = ENV["DKU_API_TICKET"]
		else
			header["Authorization"] = "Basic $(base64encode(get_context().auth * ":"))"
		end
		header["Content-Type"] = content_type
		url = get_context().url * (intern_call ? "dip/api/tintercom/" : "public/api/") * url * querystring(params)
		verbose && @info url, JSON.json(header)
		url, header
	end

	using HTTP.IOExtras

	function get_stream_read(f::Function, url; kwargs...)
		url, header = get_url_and_header(url; kwargs...)
		HTTP.open("GET", url, header; retry=false) do io
			if HTTP.iserror(startread(io))
				throw(DkuAPIException(JSON.parse(String(readavailable(io)))))
			else
				try
					f(io)
				catch
					throw(DkuException("Exception thrown while reading " * _identify(ds, params["partitions"])))
				end
			end
		end
	end


	post_multipart(url::AbstractString, path::AbstractString, filename::AbstractString=basename(path)) =
		post_multipart(url, open(path, read=true), filename)

	function post_multipart(url::AbstractString, file::IO, filename::AbstractString="file")::String
		body = HTTP.Form(Dict("file" => HTTP.Multipart(filename, file)))
		request("POST", url, body; content_type="multipart/form-data; boundary=$(body.boundary)")
	end

	function request_json(req::AbstractString, url::AbstractString, body=""; show_msg=false, kwargs...)
		raw_res = request(req, url, body; kwargs...)
		if isnothing(raw_res)
			return nothing
		end
		res = JSON.parse(raw_res)
		if show_msg && res isa Dict && haskey(res, "msg")
			@info res["msg"]
		end
		return res
	end

	function request(req, url, body=""; intern_call=false, kwargs...)
		if (typeof(body) <: AbstractDict)
			body = intern_call ? HTTP.URIs.escapeuri(body) : JSON.json(body)
		end
		res = ""
		url, header = get_url_and_header(url; intern_call=intern_call, kwargs...)
		try
			res = HTTP.request(req, url, header, body; retry=false).body |> String
		catch e
			if hasfield(typeof(e), :response)
				throw(DkuAPIException(JSON.parse(String(e.response.body))))
			else
				throw(DkuException("Exception thrown while reading " * _identify(ds, params["partitions"])))
			end
		end
		return isempty(res) ? nothing : res
	end

	delete_request(url; body="", kwargs...) = (request_json("DELETE", url, body; show_msg=true, kwargs...); nothing)