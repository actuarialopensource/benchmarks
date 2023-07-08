"""
Account changes between two timesteps for a policy holder in a [`UniversalLifeModel`](@ref).
"""
struct AccountChanges
  premium_paid::Float64
  premium_into_account::Float64
  maintenance_fee_rate::Float64
  insurance_cost::Float64
  investments::Float64
  net_changes::Float64
end

"""
Events that happen as part of a simulation timestep for a [`Model`](@ref).

These events are meant to be processed by the user in order to generate quantities of interest that
do not involve simulation-related state. This is, for example, how the [`CashFlow`](@ref) quantities are computed.
"""
mutable struct SimulationEvents
  "Month during which the events started to be simulated. Events occur between `time` and `time + Month(1) - Day(1)`."
  time::Month
  # Policy changes.
  "Policy sets where lapses occurred, along with the number of lapsed policies. Lapses occur at the middle of the month."
  const lapses::Vector{Pair{PolicySet,Float64}}
  "Policy sets where deaths occurred, along with the number of deceased policy holders. Deaths occur at the middle of the month."
  const deaths::Vector{Pair{PolicySet,Float64}}
  "Policies which expired at the beginning of the month."
  const expirations::Vector{PolicySet}
  "Amount resulting from expired or lapsed policies or for which the holder has died."
  claimed::Float64
  "Policies which started at the beginning of the month."
  const starts::Vector{PolicySet}
  expenses::Float64
  const account_changes::Vector{Pair{PolicySet,AccountChanges}}
end

SimulationEvents(time::Month) = SimulationEvents(time, Pair{PolicySet,Float64}[], Pair{PolicySet,Float64}[], PolicySet[], 0.0, PolicySet[], 0.0, Pair{PolicySet,AccountChanges}[])

"""
Simulation parametrized by a particular [`Model`](@ref).

The simulation time starts at the current date by default.
The simulation is carried out every month, producing events ([`SimulationEvents`]) corresponding
to what happened between two timesteps, i.e. from one month to the other. The simulation is nonetheless
stateful, meaning that such events may only be produced once; the next evaluation will return the events for the
timestep after that.

See also: [`next!`](@ref)
"""
mutable struct Simulation{M<:Model}
  const model::M
  "Ongoing policies which haven't reached their term yet nor lapsed and whose holders haven't died."
  const active_policies::Vector{PolicySet}
  "Policies which have yet to be started."
  const inactive_policies::Vector{PolicySet}
  "Current simulation time, incremented after every simulation step."
  time::Month
end

function Simulation(model::Model, policies, time = Month(0))
  active = filter(x -> x.policy.issued_at < time, policies)
  inactive = filter(x -> x.policy.issued_at ≥ time, policies)
  Simulation(model, active, inactive, time)
end

simulate!(sim::Simulation, n::Int) = simulate!(identity, sim, n)
function simulate!(f, sim::Simulation, n::Int)
  for i in 1:n
    events = next!(sim)
    f(events)
  end
  sim
end

simulation_range(n::Int, start::Int = 0) = Month(start):Month(1):Month(n)

"""
Perform a simulation timestep over the [`LifelibSavings`](@ref) model, returning a [`SimulationEvents`](@ref).

First, the policies which reached their term are removed, yielding claims and account changes.

Second, the policies which start from the current month are added, yielding expenses (costs for the insurance company).

Third, all account values are updated, with:
- A premium amount put into the bank account (minus fees, the load premium rate).
- Maintenance fees withdrawn from the back account.
- Insurance costs withdrawn from the back account.
- Investments realized during the previous month.

Then, at the middle of the month, deaths and lapses occur. Finally, the simulation time is incremented.
"""
function next!(sim::Simulation{LifelibSavings})
  (; model, time) = sim
  policies = sim.active_policies
  events = SimulationEvents(time)

  ### BEF_MAT
  # Remove policies which reached their term.
  filter!(policies) do set
    !matures(set, time) && return true
    # The account value is claimed by the policy holder at expiration.
    events.claimed += policy_count(set) * max(set.policy.account_value, set.policy.assured)
    push!(events.account_changes, set => AccountChanges(0, 0, 0, 0, 0, -set.policy.account_value))
    push!(events.expirations, set)
    false
  end

  ### BEF_NB
  # Add policies which start from this date.
  filter!(sim.inactive_policies) do set
    issued = time == set.policy.issued_at
    if issued
      push!(policies, set)
      push!(events.starts, set)
      events.expenses += policy_count(set) * acquisition_cost(model)
    end
    !issued
  end

  ### BEF_DECR
  # Update account values.

  for (i, set) in enumerate(policies)
    events.expenses += maintenance_cost(model, time) * policy_count(set)

    (; policy) = set
    (; account_value) = policy
    # `BEF_PREM`
    old_account_value = account_value
    premium_paid = premium_cost(policy, time)
    premium_into_account = premium_paid * (1 - policy.product.load_premium_rate)
    account_value += premium_into_account
    # `BEF_FEE`
    fee = account_value * model.maintenance_fee_rate
    account_value -= fee
    insurance_cost = model.insurance_risk_cost * amount_at_risk(model, policy, account_value)
    account_value -= insurance_cost
    # `BEF_INV`
    investments = investment_rate(model, time) * account_value
    account_value += investments
    policies[i] = @set set.policy.account_value = account_value
    push!(events.account_changes, set => AccountChanges(premium_paid, premium_into_account, fee, insurance_cost, investments, account_value - old_account_value))
  end

  # Lapses, deaths.
  # At this point we are at `time` + 0.5 (half a month after `time`).
  lapse_rate = monthly_rate(model.annual_lapse_rate)
  for (i, set) in enumerate(policies)
    c = policy_count(set)
    lapses = lapse_rate * c
    # TODO: Implement mortality with a per-policy rate based on age.
    deaths = 0.0
    (; policy) = set
    policies[i] = PolicySet(policy, c - lapses - deaths)
    events.claimed += lapses * (1 + 0.5investment_rate(model, time)) * policy.account_value
    events.claimed += deaths * max((1 + 0.5investment_rate(model, time)) * policy.account_value, policy.assured)
    !iszero(lapses) && push!(events.lapses, set => lapses)
    !iszero(deaths) && push!(events.deaths, set => deaths)
  end

  # Update simulation state.
  sim.time += Month(1)
  events
end

premium_cost(policy, time) = policy.product.premium_type == PREMIUM_SINGLE && time ≠ policy.issued_at ? 0.0 : policy.premium

matures(policy::Policy, time::Month) = time == policy.issued_at + Month(policy.term)
matures(set::PolicySet, time::Month) = matures(set.policy, time)
