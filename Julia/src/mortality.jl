abstract type MortalityModel end

Base.broadcastable(model::MortalityModel) = Ref(model)

monthly_mortality_rate(model::MortalityModel, age::Year, time::Month) = 1 - (1 - annual_mortality_rate(model, age, time)) ^ (1/12)

const model_points = read_csv("basic_term/model_point_table_10K.csv")
const issue_age = model_points[:, :age_at_entry]

Base.@kwdef struct BasicMortality <: MortalityModel
  rates::Matrix{Float64} = Matrix{Float64}(read_csv("basic_term/mort_table.csv")[:, 2:end])
  issue_age::Vector{Int} = issue_age
end

annual_mortality_rate(model::BasicMortality, year::Int, time::Int) = model.rates[year - 17, min(time, 5) + 1]
annual_mortality_rate(model::BasicMortality, year::Year, time::Month) = annual_mortality_rate(model, Dates.value(year), Dates.value(time ÷ 12))

struct ConstantMortality <: MortalityModel
  annual_mortality_rate::Float64
end

annual_mortality_rate(model::ConstantMortality, year::Year, time::Month) = model.annual_mortality_rate

const basic_mortality = BasicMortality()

const cache_monthly_basic_mortality = Dict{Tuple{Int},Vector{Float64}}()
monthly_mortality_rates(model::BasicMortality, t::Int) = 1 .- (1 .- model.rates[model.issue_age .+ (t ÷ 12) .- 17, min(t ÷ 12, 5) + 1]) .^ (1/12)
@memoize Returns(cache_monthly_basic_mortality)() monthly_basic_mortality(t) = monthly_mortality_rates(basic_mortality, t)
policies_death(t) = policies_inforce(t) .* monthly_basic_mortality(t)

const cache_policies_inforce = Dict{Tuple{Int64},Vector{Float64}}()
@memoize Returns(cache_policies_inforce)() function policies_inforce(t)::Vector{Float64}
  t == 0 && return ones(length(issue_age))
  policies_inforce(t - 1) .- policies_lapse(t - 1) .- policies_death(t - 1) .- policies_maturity(t)
end
policies_lapse(t) = (policies_inforce(t) .- policies_death(t)) .* (1 - (1 - lapse_rate(t))^(1/12))
lapse_rate(t) = max(0.1 - 0.02 * duration(t), 0.02)

policies_term() = model_points[:, :policy_term]

function policies_maturity(t)::Vector{Float64}
  (t .== 12 .* policies_term()) .* (policies_inforce(t - 1) .- policies_lapse(t - 1) .- policies_death(t - 1))
end
