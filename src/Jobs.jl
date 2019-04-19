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

list_latest_jobs(project::DSSProject=get_current_project(); limit::Integer=100) = request_json("GET", "projects/$(project.key)/jobs/?limit=$(limit)")

get_status(job::DSSJob) =  request_json("GET", "projects/$(job.project.key)/jobs/$(job.id)/")

get_logs(job::DSSJob, activity=nothing) = request("GET", "projects/$(job.project.key)/jobs/$(job.id)/log/"; params=Dict("activity" => activity))

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
    runId = request_json("POST", "projects/$(project.key)/jobs/", body)["id"]
    DSSJob(runId, projectKey)
end

abort(job::DSSJob) = request_json("POST", "projects/$(job.project.key)/jobs/$(job.id)/abort")