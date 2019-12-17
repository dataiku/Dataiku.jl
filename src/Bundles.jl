struct DSSBundle <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSBundle(name::AbstractString, project::DSSProject=get_current_project()) = new(project, name)
end

macro bundle_str(str)
    createobject(DSSBundle, str)
end

export @bundle_str
export DSSBundle

get_details(bundle::DSSBundle) = request_json("GET", "projects/$(bundle.project.key)/bundles/exported/$(bundle.id)")

download_file(bundle::DSSBundle) = get_stream("projects/$(bundle.project.key)/bundles/exported/$(bundle.id)/archive")

list_exported_bundles(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/bundles/exported")["bundles"]
list_imported_bundles(project::DSSProject=get_current_project()) = request_json("GET", "projects/$(project.key)/bundles/imported")["bundles"]

import_bundle_from_archive_file(path::AbstractString, project::DSSProject=get_current_project()) =
    request_json("POST", "projects/$(project.key)/bundles/imported/actions/importFromArchive"; params=Dict("archivePath" => path))

preload_a_bundle(bundle::DSSBundle) = request("POST", "projects/$(bundle.project.key)/bundles/imported/$(bundle.id)/actions/preload")

activate_a_bundle(bundle::DSSBundle) = request("POST", "projects/$(bundle.project.key)/bundles/imported/$(bundle.id)/actions/activate")

create_project_from_a_bundle(file::IO) = post_multipart("projectsFromBundle/", file)

create_project_from_a_bundle(archivePath::AbstractString) =
    request_json("POST", "projectsFromBundle/fromArchive"; params=Dict("archivePath" => archivePath))

create_a_new_bundle(name::AbstractString, project::DSSProject=get_current_project()) =
    request_json("PUT", "projects/$(project.key)/bundles/exported/$(name)")
