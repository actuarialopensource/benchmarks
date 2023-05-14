struct SimulationResult end

mutable struct Simulation{M<:Model}
  const model::M
  const active_policies::Vector{PolicySet}
  const inactive_policies::Vector{PolicySet}
  time::Month
  result::SimulationResult
end

function Simulation(model::Model, policies, time = Month(0))
  active = filter(x -> x.policy.issued_at < time, policies)
  inactive = filter(x -> x.policy.issued_at ≥ time, policies)
  Simulation(model, active, inactive, Month(0), SimulationResult())
end

function next!(sim::Simulation{EX4})
  (; model, time, result) = sim
  policies = sim.active_policies

  # Lapses, deaths.
  lapse_rate = monthly_rate(model.annual_lapse_rate)
  for (i, set) in enumerate(policies)
    c = policy_count(set)
    lapses = lapse_rate * c
    # TODO: Implement mortality with a per-policy rate based on age.
    deaths = 0.0
    policies[i] = PolicySet(set.policy, c - lapses - deaths)
  end

  ### BEF_MAT
  # Remove policies which reached their term.
  filter!(set -> !matures(set, time), policies)

  ### BEF_NB
  # Add policies which start from this date.
  filter!(sim.inactive_policies) do set
    issued = time == set.policy.issued_at
    issued && push!(policies, set)
    !issued
  end

  ### BEF_DECR
  # Compute premiums.

  for (i, set) in enumerate(policies)
    (; policy) = set
    # `BEF_INV` (at t-1)
    account_value = policy.account_value / set.count
    # TODO: Integrate investment income for the past month.
    # `BEF_PREM`
    account_value += policy.premium * (1 - policy.product.load_premium_rate)
    # `BEF_FEE`
    account_value *= (1 - model.account_fee_rate)
    account_value -= model.insurance_risk_cost * amount_at_risk(model, policy)
    # `BEF_INV`
    policies[i] = @set set.policy.account_value = account_value * set.count
  end

  # Update simulation state.
  sim.time += Month(1)
  sim.result = SimulationResult()
end

matures(policy::Policy, time::Month) = policy.whole_life ? false : time == policy.issued_at + Month(policy.term)
matures(set::PolicySet, time::Month) = matures(set.policy, time)
