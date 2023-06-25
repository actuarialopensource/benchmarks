python_directory() = joinpath(dirname(pkgdir(Benchmarks)), "Python")

function read_savings_model(model = "ME_EX4")
  mx = pyimport("modelx")
  timeit = pyimport("timeit")
  pyimport("openpyxl")
  mx.read_model(joinpath(python_directory(), "CashValue_$model")).Projection
end
investment_rate(proj::Py) = pyconvert(Array, proj.inv_return_table())[1, :]
ntimesteps(proj::Py) = pyconvert(Int, proj.max_proj_len())
