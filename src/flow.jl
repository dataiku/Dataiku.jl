function get_flow()
    if _is_inside_recipe()
        return JSON.parse(ENV["DKUFLOW_SPEC"])
    end
    throw(DkuException("Env variable 'DKUFLOW_SPEC' not defined."))
end

_is_inside_recipe() = haskey(ENV, "DKUFLOW_SPEC")

function get_input_partitions(ds)
    input = filter(x->x["fullName"] == full_name(ds), get_flow()["in"])[1]
    return get(input, "partitions", "")
end

function get_output_partition(ds)
    output = filter(x->x["fullName"] == full_name(ds), get_flow()["out"])[1]
    return get(output, "partition", "")
end

_check_inputs(obj::DSSObject, partitions="") = _check_inputs_or_output(obj, partitions, "in")
_check_outputs(obj::DSSObject, partition="") = _check_inputs_or_output(obj, partition, "out")

function _check_inputs_or_output(obj::DSSObject, partitions, in_or_out)
    if _is_inside_recipe()
        #=in or out=#puts = filter(x->x["fullName"] == full_name(obj), get_flow()[in_or_out])
        if isempty(puts)
            throw(DkuException("$(_type_as_string(obj)) $(full_name(obj)) cannot be used : declare it as $(in_or_out)put of your recipe."))
        end
        if !isempty(partitions)
            throw(ArgumentError("Cannot specify partitions inside recipes."))
        end
    end
end

function get_flow_variable(name::AbstractString)
    if _is_inside_recipe()
        JSON.parse(ENV["DKUFLOW_VARIABLES"])[name]
    else
        throw(DkuException("Cannot get flow variables outside of a recipe"))
    end
end
