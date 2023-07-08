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
  premiums = Float64[]
  commissions = Float64[]
  investments = Float64[]
  account_value_changes = Float64[]
  for (set, change) in events.account_changes
    premium = policy_count(set) * change.premium_paid
    push!(premiums, premium)
    push!(commissions, premium * model.commission_rate)
    push!(investments, policy_count(set) * change.investments)
    push!(account_value_changes, policy_count(set) * change.net_changes)
  end
  CashFlow(sum(premiums; init = 0.0), sum(investments; init = 0.0), events.claimed, events.expenses, sum(commissions; init = 0.0), sum(account_value_changes; init = 0.0), discount_rate(model, events.time))
end

# Adding two cashflows amounts to adding all of the fields together.
@generated function Base.:(+)(x::CashFlow, y::CashFlow)
  ex = Expr(:call, :CashFlow)
  for field in fieldnames(CashFlow)
    push!(ex.args, :(x.$field + y.$field))
  end
  ex
end

function CashFlow(sim::Simulation, model::LifelibSavings, n::Integer)
  cashflow = Ref(CashFlow())
  simulate!(sim, n) do events
    cashflow[] += CashFlow(events, model)
  end
  cashflow[]
end
