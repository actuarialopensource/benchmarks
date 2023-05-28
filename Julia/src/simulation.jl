struct AccountChanges
  premium_paid::Float64
  premium_into_account::Float64
  account_fees::Float64
  insurance_cost::Float64
  net_changes::Float64
end

struct SimulationEvents
  # Policy changes.
  lapses::Vector{Pair{PolicySet,Float64}}
  deaths::Vector{Pair{PolicySet,Float64}}
  expirations::Vector{PolicySet}
  starts::Vector{PolicySet}

  account_changes::Vector{Pair{PolicySet,AccountChanges}}
end

SimulationEvents() = SimulationEvents(Pair{PolicySet,Float64}[], Pair{PolicySet,Float64}[], PolicySet[], PolicySet[], Pair{PolicySet,AccountChanges}[])

mutable struct Simulation{M<:Model}
  const model::M
  const active_policies::Vector{PolicySet}
  const inactive_policies::Vector{PolicySet}
  time::Month
end

function Simulation(model::Model, policies, time = Month(0))
  active = filter(x -> x.policy.issued_at < time, policies)
  inactive = filter(x -> x.policy.issued_at ≥ time, policies)
  Simulation(model, active, inactive, Month(0))
end

simulate!(sim::Simulation, n::Int) = simulate!(identity, sim, n)
function simulate!(f, sim::Simulation, n::Int)
  for i in 1:n
    f(next!(sim))
  end
  sim
end

function next!(sim::Simulation{EX4})
  (; model, time) = sim
  policies = sim.active_policies
  events = SimulationEvents()

  # Lapses, deaths.
  lapse_rate = monthly_rate(model.annual_lapse_rate)
  for (i, set) in enumerate(policies)
    c = policy_count(set)
    lapses = lapse_rate * c
    # TODO: Implement mortality with a per-policy rate based on age.
    deaths = 0.0
    policies[i] = PolicySet(set.policy, c - lapses - deaths)
    push!(events.lapses, set => lapses)
  end

  ### BEF_MAT
  # Remove policies which reached their term.
  filter!(policies) do set
    !matures(set, time) && return true
    push!(events.expirations, set)
    false
  end

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
    old_account_value = account_value
    # TODO: Integrate investment income for the past month.
    # `BEF_PREM`
    premium_into_account = policy.premium * (1 - policy.product.load_premium_rate)
    account_value += premium_into_account
    # `BEF_FEE`
    account_fees = account_value * model.account_fee_rate
    account_value -= account_fees
    insurance_cost = model.insurance_risk_cost * amount_at_risk(model, policy, account_value)
    account_value -= insurance_cost
    # `BEF_INV`
    policies[i] = @set set.policy.account_value = account_value * set.count
    push!(events.account_changes, set => AccountChanges(policy.premium, premium_into_account, account_fees, insurance_cost, account_value - old_account_value))
  end

  # Update simulation state.
  sim.time += Month(1)
  events
end

matures(policy::Policy, time::Month) = policy.whole_life ? false : time == policy.issued_at + Month(policy.term)
matures(set::PolicySet, time::Month) = matures(set.policy, time)
