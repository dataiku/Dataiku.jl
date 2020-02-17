#!/usr/bin/env julia

if length(ARGS) != 2
    println("usage: julia generate_sysimage.jl PRECOMPILE.jl SYSIMAGE.so")
else
    using PackageCompilerX
    create_sysimage(:Dataiku; precompile_statements_file=ARGS[1], sysimage_path=ARGS[2])
end