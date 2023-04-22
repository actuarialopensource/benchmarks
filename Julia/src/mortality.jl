const mort_df = Matrix{Float64}(read_csv("mort_table.csv")[:, 2:end])
const model_points = read_csv("model_point_table.csv")
const issue_age = model_points[:, :age_at_entry]

Base.@kwdef struct BasicMortality
  rates::Matrix{Float64} = Matrix{Float64}(read_csv("mort_table.csv")[:, 2:end])
  issue_age::Vector{Int} = model_points[:, :age_at_entry]
end

get_annual_rate(table::BasicMortality, duration::Int) = table.rates[table.issue_age .+ duration .- 17, min(duration, 5)+1]
get_monthly_rate(table::BasicMortality, t::Int) = 1 .- (1 .- get_annual_rate(table, duration(t))).^(1/12)

const basic_mortality = BasicMortality()

const cache_monthly_basic_mortality = Dict{Tuple{Int},Any}()
@memoize Returns(cache_monthly_basic_mortality)() monthly_basic_mortality(t) = get_monthly_rate(basic_mortality, t)
policies_death(t) = policies_inforce(t) .* monthly_basic_mortality(t)

const cache_policies_inforce = Dict{Tuple{Int64},Any}()
@memoize Returns(cache_policies_inforce)() function policies_inforce(t)
  t == 0 && return ones(length(issue_age))
  policies_inforce(t - 1) .- policies_lapse(t - 1) .- policies_death(t - 1) .- policies_maturity(t)
end
policies_lapse(t) = (policies_inforce(t) .- policies_death(t)) .* (1 - (1 - lapse_rate(t))^(1/12))
lapse_rate(t) = max(0.1 - 0.02 * duration(t), 0.02)

policies_term() = model_points[:, :policy_term]

function policies_maturity(t)
  (t .== 12 .* policies_term()) .* (policies_inforce(t - 1) .- policies_lapse(t - 1) .- policies_death(t - 1))
end
