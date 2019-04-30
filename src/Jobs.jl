struct DSSJob <: DSSObject
    project::DSSProject
    id::AbstractString
    DSSJob(name::AbstractString, project::DSSProject=get_current_project()) = new(project, name)
end

macro job_str(str)
    createobject(DSSJob, str)
end

export @job_str
export DSSJob

list_latest_jobs(project::DSSProject=get_current_project(); limit::Integer=100) = request_json("GET", "projects/$(project.key)/jobs/?limit=$(limit)")

get_status(job::DSSJob) =  request_json("GET", "projects/$(job.project.key)/jobs/$(job.id)/")

get_logs(job::DSSJob, activity=nothing) = request("GET", "projects/$(job.project.key)/jobs/$(job.id)/log/"; params=Dict("activity" => activity))


function start_job_and_wait(body::AbstractDict, project::DSSProject=get_current_project())
    job = start_job(body, project)
    wait(job; no_fail=true)
    job
end

function start_job(body::AbstractDict, project::DSSProject=get_current_project())
    jobId = request_json("POST", "projects/$(project.key)/jobs/", body)["id"]
    DSSJob(jobId, project)
end

function wait(job::DSSJob; no_fail=false)
    job_state = get(get(get_status(job), "baseStatus", Dict()), "state", "")
    sleep_time = 2
    while !(job_state in ["DONE", "ABORTED", "FAILED"])
        sleep_time = (sleep_time > 300 ? 300 : sleep_time * 2)
        sleep(sleep_time)
        job_state = get(get(get_status(job), "baseStatus", Dict()), "state", "")
        if job_state in ["ABORTED", "FAILED"]
            if no_fail
                return job_state
            else
                error("Job run did not finish. Status: $job_state")
            end
        end
    end
    job_state
end

abort(job::DSSJob) = request_json("POST", "projects/$(job.project.key)/jobs/$(job.id)/abort")