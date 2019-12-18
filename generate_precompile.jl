using PackageCompiler
using Dataiku

pkg = dirname(dirname(pathof(Dataiku)))
tomlpath = joinpath(pkg, "Project.toml")
snoopfile = joinpath(pkg, "test", "runtests.jl")
precompile_file = joinpath(pkg,  "new_precompile.jl")
PackageCompiler.snoop(Dataiku, tomlpath, snoopfile, precompile_file, false)
