# we need to read the CSV file at ../data/census_dat.csv
# and then create a DataFrame from it

using DataFrames
using CSV
using Dates
using BenchmarkTools
using ExperienceAnalysis

readdir()
cd("Julia")

df = CSV.read("../data/census_dat.csv", DataFrame)
df.term_date = [d == "NA" ? missing : Date(d, "yyyy-mm-dd") for d in df.term_date]

study_end = Date(2020,12,31)
study_start = Date(2006,6,15)
df_yearly = copy(df)
continue_exposure = df.status .== "Surrender"
to = [ismissing(d) ? study_end : min(study_end,d) for d in df_yearly.term_date]
df_yearly.exposure = exposure.(
    ExperienceAnalysis.Anniversary(Year(1)),   # The basis for our exposures
    df_yearly.issue_date,                             # The `from` date
    to,                                    # the `to` date array we created above
    continue_exposure
)
df_yearly = flatten(df_yearly,:exposure)
df_yearly = filter(row -> row.exposure.to >= study_start, df_yearly)



# function benchmark_yearly(df_yearly::DataFrame, study_start::Date, study_end::Date)
#     to = [ismissing(d) ? study_end : min(study_end,d) for d in df_yearly.term_date]
#     df_yearly.exposure = exposure.(
#         ExperienceAnalysis.Anniversary(Year(1)),   # The basis for our exposures
#         df_yearly.issue_date,                             # The `from` date
#         to                                    # the `to` date array we created above
#     )
#     df_yearly = flatten(df_yearly,:exposure)
# end

# function benchmark_exposures()
#     df = CSV.read("../data/census_dat.csv", DataFrame)
#     df.term_date = [d == "NA" ? missing : Date(d, "yyyy-mm-dd") for d in df.term_date]
#     study_end = Date(2020,12,31)
#     study_start = Date(2006,6,15)
#     df_yearly = copy(df)
#     b = @benchmark benchmark_yearly($df_yearly, $study_start, $study_end)
#     print("##### Benchmark for yearly exposures #####\n\n")
#     print("mean time: ", mean(b), "\nmedian time: ", median(b), "\nmemory: ", b.memory)
# end

# benchmark_exposures()