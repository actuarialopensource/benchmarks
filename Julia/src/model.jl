abstract type Model end

mortality = read_csv("ex4/mortality.csv")

Base.@kwdef struct EX4 <: Model
  annual_discount_rate::Float64 = 0.02
  annual_lapse_rate::Float64 = 0.00
  mortality_rates_by_age::Vector{Float64} = zeros(200)
  account_fee_rate::Float64 = 0.00
  insurance_risk_cost::Float64 = 0.00 # could be set as a function of the mortality rate
end

monthly_rate(annual_rate) = (1 + annual_rate)^(1/12) - 1
# TODO: Implement a mortality model.
annual_mortality_rate(::EX4, ::Month) = 0.0
# TODO: Take the account value after the premium is versed and before account fees (`BEF_FEE`).
amount_at_risk(::EX4, policy::Policy, av_before_fees) = max(av_before_fees, policy.assured)
