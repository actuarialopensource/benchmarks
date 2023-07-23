"""
Present value of future cashflows as computed by a [`Simulation`](@ref) over a [`UniversalLifeModel`](@ref).

The present value of future cashflows is estimated from the future cashflows using a model-provided discount rate.
"""
struct CashFlow
  premiums::Float64
  investments::Float64
  claims::Float64
  expenses::Float64
  commissions::Float64
  account_value_changes::Float64
  net::Float64
  discounted::Float64
end
CashFlow() = CashFlow(0, 0, 0, 0, 0, 0, 0, 0)

function CashFlow(premiums, investments, claims, expenses, commissions, account_value_changes, discount_factor)
  net = premiums + investments - claims - expenses - commissions - account_value_changes
  CashFlow(premiums, investments, claims, expenses, commissions, account_value_changes, net, net * discount_factor)
end

function CashFlow(events::SimulationEvents, model::LifelibSavings)
  premiums = 0.0
  commissions = 0.0
  investments = 0.0
  account_value_changes = 0.0
  for (set, change) in events.account_changes
    premium = policy_count(set) * change.premium_paid
    premiums += premium
    commissions += premium * model.commission_rate
    investments += policy_count(set) * change.investments
    account_value_changes += policy_count(set) * change.net_changes
  end
  CashFlow(premiums, investments, events.claimed, events.expenses, commissions, account_value_changes, discount_rate(model, events.time))
end

function CashFlow(events::SimulationEvents, model::LifelibBasiclife)
  CashFlow(0.0, 0.0, events.claimed, events.expenses, 0.0, 0.0, discount_rate(model, events.time))
end

# Adding two cashflows amounts to adding all of the fields together.
@generated function Base.:(+)(x::CashFlow, y::CashFlow)
  ex = Expr(:call, :CashFlow)
  for field in fieldnames(CashFlow)
    push!(ex.args, :(x.$field + y.$field))
  end
  ex
end

function CashFlow(sim::Simulation)
  (; model, time) = sim
  premiums = expenses = 0.0
  inflation = inflation_factor(model, time)
  for set in sim.active_policies
    premiums += policy_count(set) * set.policy.premium
    expenses += policy_count(set) * model.annual_maintenance_cost / 12 * inflation
  end
  commissions = time < Month(12) ? premiums : 0.0
  CashFlow(premiums, 0.0, 0.0, expenses, commissions, 0.0, discount_rate(model, time))
end

function CashFlow(sim::Simulation{<:LifelibSavings}, n::Integer)
  cashflow = Ref(CashFlow())
  simulate!(sim, n) do events
    cashflow[] += CashFlow(events, sim.model)
  end
  cashflow[]
end

function CashFlow(sim::Simulation{<:LifelibBasiclife}, n::Integer)
  cashflow = Ref(CashFlow())
  compute_premiums!(sim, n)
  for i in 1:n
    events = next!(sim; callback = sim -> (cashflow[] += CashFlow(sim)))
    cashflow[] += CashFlow(events, sim.model)
  end
  cashflow[]
end
