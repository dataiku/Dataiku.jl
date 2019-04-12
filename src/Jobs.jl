struct DSSJob <: DSSObject
    projectKey::DSSProject
    id::AbstractString
    DSSJob(name::AbstractString, project::DSSProject=get_current_project()) = new(projectKey, name)
end

macro job_str(str)
    createobject(DSSJob, str)
end

export @job_str
export DSSJob

list_latest_jobs(project::DSSProject=get_current_project(); limit::Integer=100) = request("GET", "projects/$(project.key)/jobs/?limit=$(limit)")

get_status(job::DSSJob) =  request("GET", "projects/$(job.project.key)/jobs/$(job.id)/")

function get_logs(job::DSSJob, activity=nothing)
    params = Dict()
    if activity != nothing params["activity"] = activity end
    request("GET", "projects/$(job.project.key)/jobs/$(job.id)/log/"; params=params, parse_json=false)
end

# TODO
function run_job(name::AbstractString, project::DSSProject=get_current_project(); partitions=nothing, job_type::AbstractString="RECURSIVE_FORCED_BUILD")
    body = Dict(
        "outputs" => [Dict(
            "projectKey" => projectKey,
            "id"         => name
            )],
        "type" => job_type
    )
    if partitions != nothing body["outputs"][1]["partitions"] = partitions end
    runId = request("POST", "projects/$(project.key)/jobs/", body)["id"]
    DSSJob(runId, projectKey)
end

abort(job::DSSJob) = request("POST", "projects/$(job.project.key)/jobs/$(job.id)/abort")