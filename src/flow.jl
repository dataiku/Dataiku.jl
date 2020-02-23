function get_flow()
    if _is_inside_recipe()
        return JSON.parse(ENV["DKUFLOW_SPEC"])
    end
    throw(DkuException("Env variable 'DKUFLOW_SPEC' not defined."))
end

_is_inside_recipe() = haskey(ENV, "DKUFLOW_SPEC")

get_flow_outputs(obj::DSSObject) = _get_flow_inputs_or_outputs(obj, "out")
get_flow_inputs(obj::DSSObject) = _get_flow_inputs_or_outputs(obj, "in")

function _get_flow_inputs_or_outputs(obj::DSSObject, option)
    puts = filter(x->x["fullName"] == full_name(obj), get_flow()[option])
    if isempty(puts)
        throw(DkuException("$(_type_as_string(obj)) $(obj.name) cannot be used : declare it as " * option * "put of your recipe."))
    end
    return get_flow()[option][1]
end

function get_flow_variable(name::AbstractString)
    if _is_inside_recipe()
        JSON.parse(ENV["DKUFLOW_VARIABLES"])[name]
    else
        throw(DkuException("Cannot get flow variables outside of a recipe"))
    end
end
