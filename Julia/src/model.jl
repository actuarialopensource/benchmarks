abstract type Model end

Base.broadcastable(model::Model) = Ref(model)

mortality = read_csv("ex4/mortality.csv")

Base.@kwdef struct EX4 <: Model
  annual_discount_rate::Float64 = 0.02
  annual_lapse_rate::Float64 = 0.00
  mortality_rates_by_age::Vector{Float64} = zeros(200)
  maintenance_fee_rate::Float64 = 0.00
  commission_rate::Float64 = 0.05
  insurance_risk_cost::Float64 = 0.00 # could be set as a function of the mortality rate
  investment_rng_numbers::Vector{Float64} = zeros(10000) # the dimension is the number of possible timesteps
  "One-time cost for new policies."
  acquisition_cost::Float64 = 5000.0
  "Roughly estimated average for the inflation rate."
  inflation_rate::Float64 = 0.01
  "Annual maintenance cost per policy."
  annual_maintenance_cost::Float64 = 500.0
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

acquisition_cost(model::EX4) = model.acquisition_cost
maintenance_cost(model::EX4, t::Month) = model.annual_maintenance_cost / 12 * (1 + model.inflation_rate)^(Dates.value(t)/12)
