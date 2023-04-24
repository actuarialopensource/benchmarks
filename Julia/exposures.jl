using DataFrames
using CSV
using Dates
using BenchmarkTools
using ExperienceAnalysis
using DayCounts

function expsoures_ExperienceAnalysis(
    df_yearly::DataFrame,
    study_start::Date,
    study_end::Date,
)
    continue_exposure = df_yearly.status .== "Surrender"
    df_yearly.exposure =
    ExperienceAnalysis.exposure.(
            ExperienceAnalysis.Anniversary(Year(1)),   # The basis for our exposures
            df_yearly.issue_date,                             # The `from` date
            df_yearly.term_date,                                    # the `to` date array we created above
            continue_exposure;
            study_start=study_start,
            study_end = study_end,
            left_partials=false
        )
    df_yearly = flatten(df_yearly, :exposure)
    df_yearly.exposure_fraction =
        map(e -> yearfrac(e.from, e.to, DayCounts.Thirty360()), df_yearly.exposure)
    return df_yearly
end



function run_exposure_benchmarks()
    df = CSV.read(joinpath(dirname(@__DIR__), "data", "census_dat.csv"), DataFrame)
    df.term_date = [d == "NA" ? nothing : Date(d, "yyyy-mm-dd") for d in df.term_date]
    study_end = Date(2020, 2, 29)
    study_start = Date(2006, 6, 15)
    df_yearly_exp = copy(df)
    result_exp = expsoures_ExperienceAnalysis(copy(df), study_start, study_end)
    b_exp = @benchmark expsoures_ExperienceAnalysis($df_yearly_exp, $study_start, $study_end)
    
    return Dict(
        "Julia ExperienceAnalysis.jl" => Dict(
            "num_rows" => size(result_exp, 1),
            "mean" => string(mean(b_exp)),
        )
    )
end


