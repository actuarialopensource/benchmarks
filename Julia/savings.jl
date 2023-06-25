using Benchmarks
using BenchmarkTools

function run_savings_benchmark()
  proj = read_savings_model()
  policies = policies_from_lifelib(proj)
  model = EX4(investment_rates = investment_rate(proj))
  n = ntimesteps(proj)
  savings_benchmark = @benchmark CashFlow(sim, $model, $n).discounted setup = begin
    sim = Simulation($model, $policies)
  end
  savings = CashFlow(Simulation(model, policies), model, n).discounted
  Dict(
    "Julia Benchmarks savings" => Dict(
      "mean" => string(mean(savings_benchmark)),
      "result" => savings,
    )
  )
end
