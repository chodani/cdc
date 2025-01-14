using cdc, CSV, DataFrames, Deneb, MethodChains, PlotlyJS, Serialization, Dates, HTTP
# what does this line really do?
MethodChains.init_repl()

inputdeaths = "WeeklyProvisionalDeaths.csv" 
inputpopulation = "US_Populations.csv"
inputcovid = "COVID.csv"
inputcapitals = "us-state-capitals.csv"

read_deaths(inputdeaths) |> describe

describe(read_deaths(inputdeaths), :eltype, :nuniqueall, :nmissing, :min, :max)
size(read_deaths(inputdeaths))
let
    read_deaths(inputdeaths).{
        unique(it.geographic_area)
        show(stdout, "text/plain", it)
    }
end
# find total deaths by states, could also look into specific causes
read_deaths(inputdeaths).{
    groupby(it, :"geographic_area")         
    combine(it, :"all_cause" => sum => :total_deaths)
    sort(it, :total_deaths, rev = true)
    them
}

read_deaths(inputdeaths).{
	filter(row -> row."geographic_area" != "United States", it)	filter(row -> row."geographic_area" != "United States", it)
    groupby(it, :"mmwr_year")												groupby(it, :"mmwr_week")			                      
    combine(it, :"all_cause" => sum => :total_deaths)						combine(it, :"all_cause" => sum => :total_deaths)
    sort(it, :total_deaths, rev = true)										sort(it, :total_deaths, rev = true)
    them
}

# find total covid deaths by week in order of deaths descending
read_deaths(inputdeaths).{
    filter(row -> row."geographic_area" == "United States", it)
    groupby(it, :"week_ending_date")    
    combine(it, :"covid_19_u071_underlying_cause_of_death" => sum => :covid_deaths)
    sort(it, :covid_deaths, rev = true)
    them
}

# temporal view of covid deaths
read_deaths(inputdeaths).{
    filter(row -> row."geographic_area" == "United States", it)
    groupby(it, :"week_ending_date")    
    combine(it, :"covid_19_u071_underlying_cause_of_death" => sum => :covid_deaths)
    them
}

# show covid deaths through time (but why do i need sum?)
read_deaths(inputdeaths).{
	filter(row -> row."geographic_area" == "United States", it)
    Data(it) * Mark(:area) * Encoding(
        x=field("week_ending_date"),
        y=field("sum(covid_19_u071_underlying_cause_of_death)"))
}

# show all deaths through time
read_deaths(inputdeaths).{
	filter(row -> row."geographic_area" == "United States", it)
    Data(it) * Mark(:area) * Encoding(
        x=field("week_ending_date"),
        y=field("sum(all_cause)"))
}

# find death rate among states (what is the point of "them"?)
read_deaths(inputdeaths).{
	groupby(it, :geographic_area)
	combine(it, :all_cause => sum => :total_deaths)
	innerjoin(it, read_population(inputpopulation), on = :geographic_area)
	transform(it, [:total_deaths, Symbol("2023")] => ((total_deaths, population) -> total_deaths ./ population) => :rate)
	sort(it, :rate, rev = true)
}

# covid deaths by states visualized
read_deaths(inputdeaths).{
    Data(it) * Mark(:area, opacity = 0.3) * Encoding(
        x=field("week_ending_date"),
        y=field("sum(covid_19_u071_underlying_cause_of_death)", stack=nothing),
        color="geographic_area")
}



head(read_covid("COVID.csv"), 5)

describe(CSV.read(inputcovid, DataFrame), :nuniqueall, :nmissing)

store_covid(inputcovid, "covid.serial")



usa = Data(
    url="https://vega.github.io/vega-datasets/data/us-10m.json",
    format=(type=:topojson, feature=:states),
) * Mark(
    :geoshape, fill=:lightgray, stroke=:white
)

weekonecovid = read_deaths(inputdeaths).{
        filter(row -> row."week_ending_date" == Date(2020,1,4), it)
        innerjoin(it, read_capitals(inputcapitals), on = :geographic_area)
        select!(it, :geographic_area, :week_ending_date, :covid_19_u071_underlying_cause_of_death, :capital, :latitude, :longitude)
        them
    }


points = Data(
    url="https://vega.github.io/vega-datasets/data/airports.csv"
) * Mark(:circle) * transform_aggregate(
    latitude="mean(latitude)",
    longitude="mean(longitude)",
    count="count()",
    groupby=:state,
) * Encoding(
    longitude=:longitude,
    latitude=:latitude,
    detail=:state,
    size=field("count:Q", title="Number of Airports"),
)

points = Data(
    weekonecovid
) * Mark(:circle)
  * Encoding(
    longitude=:longitude,
    latitude=:latitude,
    detail=:geographic_area,
    size=field(:covid_19_u071_underlying_cause_of_death, title="Number of Airports"),
)


base = projection("albersUsa") * vlspec(
    width=500,
    height=300
) * title("Covid Deaths")

chart = base * (usa + points)



http_response = HTTP.get("https://vega.github.io/vega-datasets/data/airports.csv")

file = CSV.File(http_response.body)

