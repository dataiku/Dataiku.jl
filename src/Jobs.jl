struct DSSJob <: DSSObject
    id::AbstractString
    projectKey::AbstractString
    DSSJob(name::AbstractString, projectKey=get_projectKey()) = new(name, projectKey)
end

macro job_str(str)
    createobject(DSSJob, str)
end

export @job_str
export DSSJob

function list_latest_jobs(projectKey=get_projectKey(); limit::Integer=100)
    request("GET", "projects/$(projectKey)/jobs/?limit=$(limit)")
end

get_status(job::DSSJob) =  request("GET", "projects/$(job.projectKey)/jobs/$(job.id)/")

function get_logs(job::DSSJob, activity=nothing)
    params = Dict()
    if activity != nothing params["activity"] = activity end
    request("GET", "projects/$(job.projectKey)/jobs/$(job.id)/log/"; params=params, parse_json=false)
end

# TODO
function run_job(name::AbstractString, projectKey=get_projectKey(); partitions=nothing, job_type::AbstractString="RECURSIVE_FORCED_BUILD")
    body = Dict(
        "outputs" => [Dict(
            "projectKey" => projectKey,
            "id"         => name
            )],
        "type" => job_type
    )
    if partitions != nothing body["outputs"][1]["partitions"] = partitions end
    runId = request("POST", "projects/$(projectKey)/jobs/", body)["id"]
    return DSSJob(runId, projectKey)
end

abort(job::DSSJob) = request("POST", "projects/$(job.projectKey)/jobs/$(job.id)/abort")