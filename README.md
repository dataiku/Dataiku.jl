# Overview
This package provides an interface to use DSS remotely and to create recipes/notebooks in [DSS](https://www.dataiku.com/dss/)

# Usage
## Reading Data
### Load a full Dataset
To read a dataset into a `DataFrame` :
```julia
using Dataiku, DataFrames
import Dataiku: get_dataframe

df = get_dataframe(dataset"PROJECTKEY.myDataset")
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

### Load a Dataset as a Channel
To be able to read data by chunk, without loading all the data. The same keyword parameters can be given.
```julia
chnl = Dataiku.iter_dataframes(dataset"myDataset", 1000)
first_thousand_row = take!(chnk)
second_thousand_row = take!(chnk)
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
## Writing Data
The output datasets must already exist in the project.

### Full dataframes
```julia
Dataiku.write_with_schema(dataset"myOutputDataset", df)
Dataiku.write_from_dataframe(dataset"myOutputDataset", df) # will not update the schema
```

### Stream the data
It is also possible to write datasets chunk by chunk with julia [Channels](https://docs.julialang.org/en/v1/manual/parallel-computing/#Channels)
All the dataframes put into the channel will be written
```julia
Dataiku.write_with_schema(dataset"myOutputDataset") do chnl
    for chunk in data
        new_chunk = modify_chunk(chunk)
        put!(chnl, new_chunk)
    end
end
```
```julia
chnl = Dataiku.get_writting_chnl(dataset"myOutputDataset")
for chunk in data
    new_chunk = modify_chunk(chunk)
    put!(chnl, new_chunk)
end
close(chnl) # Closing this channel is required
```
It gives to possibility to modify big datasets without loading the entire dataset in memory.
```julia
input = Dataiku.iter_dataframes(dataset"input_dataset", 500)
  Dataiku.write_dataframe(dataset"output") do chnl
      for chunk in input
          put!(chnl, chunk)
      end
  end
```

### Keywords parameters
- `partition::AbstractString` : specify the partition to write.
- `overwrite::Bool=true` : if `false`, appends the data to the already existing dataset.

## API functions
The package also implements an interface to most of the calls of the [DSS REST API](https://doc.dataiku.com/dss/api/5.0/rest/)

### Project initialization
When using the package inside DSS (recipe or notebook) the projectKey doesn't need to be initialized. Otherwise, you may want to use `Dataiku.set_current_project(project"MYPROJECTKEY")`.
If no project key is initialized, or to use objects for other projects, it's needed to indicate the project during the object creation :
```julia
dataset"PROJECTKEY.datasetname"
DSSDataset(project"PROJECTKEY", "datasetname") # this is exactly equivalent to the last line
...
```

### Context initialization
To use the package outside of DSS, a url to the instance and an API key or a DKU Ticket is needed. 
API key can be retrieved in DSS, Administration -> Security

There are 2 ways to initialize it
#### with config.json file
Create this json file in you're home path `$HOME/.dataiku/config.json`
```
{
  "dss_instances": {
    "default": {
      "url": "http://localhost:XXXX/",
      "api_key": "$(APIKEY secret)"
    }
  },
  "default_instance": "default"
}
```
#### with init_context function
```julia
Dataiku.init_context(url::AbstractString, auth::AbstractString)
```

### Types
The Package implements DSSTypes to interact with different DSS objects

`DSSAnalysis` `DSSBundle` `DSSDataset` `DSSDiscussion` `DSSManagedFolder` `DSSJob` `DSSMLTask` `DSSMacro` `DSSModelVersion` `DSSProject` `DSSRecipe` `DSSSavedModel` `DSSScenario` `DSSScenarioRun` `DSSTrainedModel` `DSSTriggerFire`

 
*These types are only indicators and don't store any data or metadata.*

You can have details about what you can do with these types in notebooks or julia REPL like this : `?DSSDataset`

For more accessibility, str_macros exist to create most of these types :
* `dataset"mydataset"` is equivalent to `DSSDataset("mydataset")`
* `dataset"PROJECTKEY.mydataset"` => `DSSDataset("mydataset", DSSProject("PROJECTKEY"))`
* `project"PROJECTKEY"` => `DSSProject("PROJECTKEY")`
* `recipes"myrecipe"` => `DSSRecipes("myrecipe")`
* `recipes"myscenario"` => `DSSScenario("myscenario")`

## Tests

A running DSS instance and a config file (`$HOME/.dataiku/config.json`) are required to run the tests.
config.json :
```json
{
  "dss_instances": {
    "default": {
      "url": INSTANCE_URL,
      "api_key": API_KEY_SECRET
    }
  },
  "default_instance": "default"
}
```