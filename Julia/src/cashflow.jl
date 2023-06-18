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

function CashFlow(premiums, investments, claims, expenses, commissions, account_value_changes, discount_factor)
  net = premiums + investments - claims - expenses - commissions - account_value_changes
  CashFlow(premiums, investments, claims, expenses, commissions, account_value_changes, net, net * discount_factor)
end

function CashFlow(events::SimulationEvents, model::EX4)
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
