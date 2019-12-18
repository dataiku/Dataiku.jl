using PackageCompiler
using Dataiku

pkg = dirname(dirname(pathof(Dataiku)))
sysimg = compile_incremental(joinpath(pkg, "Project.jl"), joinpath(pkg, "precompile.jl"))[1]

println("Sysimg built : ", sysimg)