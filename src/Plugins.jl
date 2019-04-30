list_installed_plugins() = request_json("GET", "plugins/")

download_a_plugin(pluginId) = get_stream("plugins/$(pluginId)/download")

list_files_in_plugin(pluginId) = request_json("GET", "plugins/$(pluginId)/contents/")

download_file(pluginId, path) = get_stream("plugins/$(pluginId)/contents/$(path)")

upload_file_to_plugin(pluginId, path, file) = post_multipart("plugins/$(pluginId)/contents/$(path)", file)
