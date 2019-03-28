struct DSSBundle <: DSSObject
    id::AbstractString
    projectKey::AbstractString
    DSSBundle(name, projectKey=get_projectKey()) = new(name, projectKey)
end

macro bundle_str(str)
    createobject(DSSBundle, str)
end

export @bundle_str
export DSSBundle


function get_details(bundle::DSSBundle)
    request("GET", "projects/$(bundle.projectKey)/bundles/exported/$(bundle.id)")
end

function download_file(bundle::DSSBundle)
    request("GET", "projects/$(bundle.projectKey)/bundles/exported/$(bundle.id)/archive"; stream=true)
end

function list_exported_bundles(projectKey=get_projectKey())
    request("GET", "projects/$(projectKey)/bundles/exported")["bundles"]
end

function list_imported_bundles(projectKey=get_projectKey())
    request("GET", "projects/$(projectKey)/bundles/imported")["bundles"]
end


function import_bundle_from_archive_file(path::AbstractString)
    request("POST", "projects/$(get_projectKey())/bundles/imported/actions/importFromArchive"; params=Dict("archivePath" => path))
end

function preload_a_bundle(bundle::DSSBundle)
	request("POST", "projects/$(bundle.projectKey)/bundles/imported/$(bundle.id)/actions/preload")
end

function activate_a_bundle(bundle::DSSBundle)
	request("POST", "projects/$(bundle.projectKey)/bundles/imported/$(bundle.id)/actions/activate")
end

function create_project_from_a_bundle(file::IO)
	post_multipart("projectsFromBundle/", file)
end

function create_project_from_a_bundle(archivePath::AbstractString)
    request("POST", "projectsFromBundle/fromArchive"; params=Dict("archivePath" => archivePath))
end

function create_a_new_bundle(name::AbstractString, projectKey=get_projectKey()) 
    request("PUT", "projects/$(projectKey)/bundles/exported/$(name)")
end