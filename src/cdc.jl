module cdc

using CSV, DataFrames, Dates, MethodChains, Serialization
import TableTransforms: StdNames

export read_deaths, read_population, store_covid, read_capitals

"""
    read_deaths(inputpath)

Read in a weelky deaths into dataframes and clean up columns
"""
function read_deaths(inputpath)
    df = CSV.read(inputpath, DataFrame)
    select!(df, Not(:"Data As Of"))
    select!(df, 1:19)
    df = coalesce.(df, 3)
    df = df |> StdNames(:snake)
    rename!(df,:"jurisdiction_of_occurrence" => :geographic_area)
    return df
end

"""
    read_population(inputpath)

Read in population data on states
"""
function read_population(inputpath)
    df = CSV.read(inputpath, DataFrame; header = 4, footerskip = 6)
    transform!(df, [:"1-Apr-20", :"2020", :"2021", :"2022", :"2023"] .=> (x -> parse.(Int, replace.(x, "," => ""))), renamecols = false)
    return df |> StdNames(:snake)
end

function read_capitals(inputpath)
    df = CSV.read(inputpath, DataFrame)
    rename!(df, :name => :geographic_area, :description => :capital)
    return df
end

"""
    store_covid(inputname)

Read in covid data
"""
function store_covid(inputname, outfilename)
    df = CSV.read(inputname, DataFrame)
    serialize(outfilename, df)
    #takes 40+ minutes to read in data...
end

end # module cdc



