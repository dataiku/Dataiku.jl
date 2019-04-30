const DKU_OBJECT_MAP = Dict(
    DSSDataset => "DATASET",
    DSSRecipe => "RECIPE",
    DSSScenario => "SCENARIO",
    DSSAnalysis => "ANALYSIS",
    DSSSavedModel => "SAVED_MODEL",
    DSSFolder => "MANAGED_FOLDER",
    DSSProject => "PROJECT"
)

function get_type(str::AbstractString)
    for (a, b) in DKU_OBJECT_MAP
        if b == str
            return a
        end
    end
end

list_discussions(object::DSSObject) = list_discussions(get_name_or_id(object), DKU_OBJECT_MAP[typeof(object)], get_project(object))

list_discussions(objectId::AbstractString, objectType::AbstractString, project::DSSProject=get_current_project()) =
    request_json("GET", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/")

struct DSSDiscussion
    object::DSSObject
    id::AbstractString
    DSSDiscussion(object, id) = new(object, id)
    function DSSDiscussion(dict::AbstractDict)
        type = get_type(dict["objectType"])
        object = type <: DSSProject ? type(dict["projectKey"]) : type(dict["objectId"], DSSProject(dict["projectKey"]))
        new(object, dict["id"])
    end
end

export DSSDiscussion

get_settings(discussion::DSSDiscussion) = get_discussion(discussion.object, discussion.id)
get_discussion(object::DSSObject, id::AbstractString) = get_discussion(get_name_or_id(object), DKU_OBJECT_MAP[typeof(object)], id, get_project(object))
get_discussion(objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, project::DSSProject=get_current_project()) =
    request_json("GET", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/$(discussionId)")

set_settings(discussion::DSSDiscussion, settings) = update_discussion(discussion.object, discussion.id, settings)
update_discussion(object::DSSObject, id, discussion) = update_discussion(get_name_or_id(object), DKU_OBJECT_MAP[typeof(object)], id, discussion, get_project(object))
update_discussion(objectId::AbstractString, objectType, discussionId, discussion::AbstractDict, project::DSSProject=get_current_project()) =
    request_json("PUT", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/$(discussionId)", discussion)


create_discussion(object::DSSObject, topic, reply) = create_discussion(get_name_or_id(object), DKU_OBJECT_MAP[typeof(object)], topic, reply, get_project(object))
function create_discussion(objectId::AbstractString, objectType::AbstractString, topic, reply, project::DSSProject=get_current_project())
    data = Dict(
        "topic" => topic,
        "reply" => reply
    )
    request_json("POST", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/", data)
end

reply(discussion::DSSDiscussion, message) = reply(discussion.object, discussion.id, message)
reply(object::DSSObject, id, message) = reply(get_name_or_id(object), DKU_OBJECT_MAP[typeof(object)], id, message, get_project(object))
reply(objectId::AbstractString, objectType::AbstractString, discussionId::AbstractString, message, project::DSSProject=get_current_project()) =
    request_json("POST", "projects/$(project.key)/discussions/$(objectType)/$(objectId)/$(discussionId)/replies/", Dict("reply" => message))