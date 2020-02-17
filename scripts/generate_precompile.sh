#!/usr/bin/env bash

# There should be a ~/.dataiku/config.json file existing with url and api key
# of an existing dss instance for this script to work

script_path=$(dirname $0)

julia --color=yes --trace-compile=$script_path"/../new_precompile.jl" $script_path"/../test/runtests.jl"
