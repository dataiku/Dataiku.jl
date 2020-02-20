function get_custom_variables(project::DSSProject=get_current_project(); resolved=true)
    request_json("GET", "projects/$(project.key)/variables"*(resolved ? "-resolved" : ""))
end

get_local_variables(project::DSSProject=get_current_project()) = _get_variables("local", project)
add_local_variable(key, value, project::DSSProject=get_current_project()) = add_local_variable(key => value, project)
add_local_variable(variable::Pair, project::DSSProject=get_current_project()) = _add_variable(variable, "local", project)

get_standard_variables(project::DSSProject=get_current_project()) = _get_variables("standard", project)
add_standard_variable(key, value, project::DSSProject=get_current_project()) = add_standard_variable(key => value, project)
add_standard_variable(variable::Pair, project::DSSProject=get_current_project()) = _add_variable(variable, "standard", project)

_get_variables(variable_type, project::DSSProject=get_current_project()) = get_custom_variables(project; resolved=false)[variable_type]

function _add_variable(variable::Pair, variable_type, project::DSSProject=get_current_project())
    variables = get_custom_variables(project; resolved=false)
    variables[variable_type][variable.first] = variable.second
    set_custom_variables(variables, project)
end

function set_custom_variables(body, project::DSSProject=get_current_project())
    request_json("PUT", "projects/$(project.key)/variables", body)
end