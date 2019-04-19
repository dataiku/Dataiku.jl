list_installed_plugins() = request_json("GET", "plugins/")

download_a_plugin(pluginId::AbstractString) = request_stream("GET", "plugins/$(pluginId)/download")

list_files_in_plugin(pluginId::AbstractString) = request_json("GET", "plugins/$(pluginId)/contents/")

download_file(pluginId::AbstractString, path::AbstractString) = request_stream("GET", "plugins/$(pluginId)/contents/$(path)")

function upload_file_to_plugin(pluginId::AbstractString, path::AbstractString, file)
    filename = String(split(path, "/")[end])
    post_multipart("plugins/$(pluginId)/contents/$(path)", file, filename)
end

# API urls doesn't exist

# function upload_a_new_plugin(pluginId::AbstractString, filepath::AbstractString) 
# 	post_multipart("$(public_url)/plugins/$(pluginId)/upload", filepath)
# end

# function update_a_plugin(pluginId::AbstractString, filepath::AbstractString)
# 	post_multipart("$(public_url)/plugins/$(pluginId)/update", filepath)
# end

