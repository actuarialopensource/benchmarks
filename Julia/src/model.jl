abstract type Model end

Base.broadcastable(model::Model) = Ref(model)

mortality = read_csv("ex4/mortality.csv")

Base.@kwdef struct EX4 <: Model
  annual_discount_rate::Float64 = 0.02
  annual_lapse_rate::Float64 = 0.00
  mortality_rates_by_age::Vector{Float64} = zeros(200)
  account_fee_rate::Float64 = 0.00
  insurance_risk_cost::Float64 = 0.00 # could be set as a function of the mortality rate
  investment_rng_numbers::Vector{Float64} = zeros(10000) # the dimension is the number of possible timesteps
end

monthly_rate(annual_rate) = (1 + annual_rate)^(1/12) - 1
# TODO: Implement a mortality model.
annual_mortality_rate(::EX4, ::Month) = 0.0
# TODO: Take the account value after the premium is versed and before account fees (`BEF_FEE`).
amount_at_risk(::EX4, policy::Policy, av_before_fees) = max(av_before_fees, policy.assured)

function investment_rate(model::EX4, t::Month)
  # These parameters are currently hardcoded in the Python implementation.
  μ = 0.02; σ = 0.03; Δt = 1/12
  i = 1 + Dates.value(t)
  exp((μ - σ^2/2)Δt + σ√(Δt) * model.investment_rng_numbers[i]) - 1
end
