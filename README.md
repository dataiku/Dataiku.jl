# Overview
This package provides an interface to use and create recipes in [DSS](https://www.dataiku.com/dss/)

# Usage
## Reading functions
### Load a full Dataset
To read a dataset into a `DataFrame` :
```julia
using Dataiku, DataFrames
import Dataiku: get_dataframe

df = get_dataframe(dataset"PROJECTKEY, myDataset")
```
#### Keywords parameters
- `partitions::AbstractArray` : specify the partitions wanted
- `infer_types::Bool=true` : uses the types detected by TextParse.jl rather than the DSS schema
- `limit::Integer` : Limits the number of rows returned
- `ratio::AbstractFloat` : Limits the ratio to at n% of the dataset
- `sampling::AbstractString="head"` : Sampling method, if
    * `head` returns the first rows of the dataset. Incompatible with ratio parameter.
    * `random` returns a random sample of the dataset
    * `random-column` returns a random sample of the dataset. Incompatible with limit parameter.
- `sampling_column::AbstractString` : Select the column used for "columnwise-random" sampling

Examples :
```julia
get_dataframe(dataset"myDataset")
get_dataframe(dataset"myDataset", [:col1, :col2, :col5]; partitions=["2019-02", "2019-03"])
get_dataframe(dataset"PROJECTKEY.myDataset"; infer_types=false, limit=200, sampling="random")
```

### Load a Dataset as a Channel to iterate
To be able to read data by chunk, without loading all the data. The same keyword parameters can be given.
```julia
chnl = Dataiku.iter_dataframes(dataset"myDataset", 1000)
first_thousand_row = take!(chnk)
```
It is then possible to iterate through it
```julia
for chunk in chnl
    do_stuff(chunk)
end
```
Iteration row by row with DataFrameRows or tuples is also possible
```julia
iter_rows(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
iter_tuples(ds::DSSDataset, columns::AbstractArray=[]; kwargs...)
```
## Writting functions
```julia
Dataiku.write_with_schema(dataset"myOutputDataset", df)
Dataiku.write_from_dataframe(dataset"myOutputDataset", df) # will not upgrade the schema
```
The output dataset must already exist in the project.
#### Keywords parameters
- `partition::AbstractString` : specify the partition to write.
- `overwrite::Bool=true` : if `false`, appends the data to the already existing dataset.
