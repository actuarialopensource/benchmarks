include("predict.jl")
using CSV
using DataFrames
using MortalityTables
using OffsetArrays
using BenchmarkTools
# read the CSV modelpoints.csv, disable multithreading https://discourse.julialang.org/t/disable-sentinelarrays-for-csv-read/54843/5
mps = CSV.read("./modelpoints.csv", DataFrame; ntasks=1)


function get_monthly_qs(mortality_tbls, mp_mortality_tbls::Vector{Int}, issue_ages::Vector{Int}, max_duration::Int)
    qs = [
        mortality_tbls[mp_mortality_tbl][issue_age][issue_age.+duration]
        for (mp_mortality_tbl, issue_age) in zip(mp_mortality_tbls, issue_ages),
        duration in 1:max_duration
    ]
    return 1 .- (1 .- qs) .^ (1.0 / 12.0)
end

function get_monthly_ws(lapse_predictor::LapsePredictor, max_duration::Int)
    ws = [lapse_predictor(duration) for duration in 1:max_duration]
    ws = reduce(hcat, ws)
    ws = min.(ws, 1.0) #Poisson has some out of bounds
    return 1 .- (1 .- ws) .^ (1.0 / 12.0)
end

function project_monthly_claims(monthly_qs::Matrix{Float64}, monthly_ws::Matrix{Float64}, face_amt::Vector{Float64})
    pols_if = ones(size(face_amt))
    timesteps = 12 * size(monthly_qs, 2)
    claims = zeros(timesteps)
    for t in 0:(timesteps-1)
        pols_death = @views pols_if .* monthly_qs[:, 1+(t÷12)]
        monthly_claims = pols_death .* face_amt
        claims[t+1] = sum(monthly_claims)
        # lapses after deaths
        pols_lapse = @views (pols_if - pols_death) .* monthly_ws[:, 1+(t÷12)]
        pols_if = pols_if - pols_death - pols_lapse
    end
    return claims
end

function runner(
    issue_age::Vector{Int},
    riskclass_encoded::Vector{Int},
    face_amounts::Vector{Float64},
    face_amounts_encoded::Vector{Int},
    premium_mode_encoded::Vector{Int},
    premium_jump_encoded::Vector{Int},
    mp_mortality_tables::Vector{Int},
)
    mortality_tbls = OffsetArray([MortalityTables.table(i).select for i in 3299:3308], 3299:3308)
    monthly_qs = get_monthly_qs(mortality_tbls, mp_mortality_tables, issue_age, 20)
    lapse_predictor = LapsePredictor(issue_age, riskclass_encoded, face_amounts_encoded, premium_mode_encoded, premium_jump_encoded)
    monthly_ws = get_monthly_ws(lapse_predictor, 20)
    monthly_claims = project_monthly_claims(monthly_qs, monthly_ws, face_amounts)
    return monthly_claims
end

b = @benchmark runner(
    $mps.issue_age,
    $mps.riskclass_encoded,
    $mps.face_amounts,
    $mps.face_amounts_encoded,
    $mps.premium_mode_encoded,
    $mps.premium_jump_encoded,
    $mps.mortality_tables,
)

print("mean time: ", mean(b), "\nmedian time: ", median(b), "\nmemory: ", b.memory)