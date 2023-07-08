python_directory() = joinpath(dirname(pkgdir(Benchmarks)), "Python")

"Read a specific `savings` model, such as `SE_EX4` or `ME_EX4`."
function read_savings_model(model = "ME_EX4")
  mx = pyimport("modelx")
  timeit = pyimport("timeit")
  pyimport("openpyxl")
  mx.read_model(joinpath(python_directory(), "CashValue_$model")).Projection
end
investment_rate(proj::Py) = pyconvert(Array, proj.inv_return_table())[1, :]
ntimesteps(proj::Py) = pyconvert(Int, proj.max_proj_len())

"Set the policy sets (model points) used by `proj` to be `policies`."
function use_policies!(proj::Py, policies)
  csv = to_csv(policies)
  pd = pyimport("pandas")
  df = pd.read_csv(csv)
  proj.model_point_table = df
  proj
end
