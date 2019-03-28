list_installed_plugins() = request("GET", "plugins/")

download_a_plugin(pluginId::AbstractString) = request("GET", "plugins/$(pluginId)/download"; stream=true)

list_files_in_plugin(pluginId::AbstractString) = request("GET", "plugins/$(pluginId)/contents/")

download_file(pluginId::AbstractString, path::AbstractString) = request("GET", "plugins/$(pluginId)/contents/$(path)"; stream=true)

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

