using LifeSimulator
using BenchmarkTools
using PythonCall: pyimport

python_directory() = joinpath(dirname(@__DIR__), "Python")

"Read a specific `savings` model, such as `SE_EX4` or `ME_EX4`."
function read_savings_model(model = "ME_EX4"; dir = python_directory())
  mx = pyimport("modelx")
  mx.read_model(joinpath(dir, "CashValue_$model")).Projection
end

function run_savings_benchmark()
  proj = read_savings_model()
  proj.scen_size = 1
  policies = policies_from_csv("savings/model_point_table_10K.csv")
  use_policies!(proj, policies)
  model = LifelibSavings(investment_rates = investment_rate(proj))
  n = ntimesteps(proj)
  savings_benchmark = @benchmark CashFlow(sim, $n).discounted setup = begin
    sim = Simulation($model, $policies)
  end
  savings = CashFlow(Simulation(model, policies), n).discounted
  Dict(
    "Julia Benchmarks savings" => Dict(
      "mean" => string(mean(savings_benchmark)),
      "result" => savings,
    )
  )
end
