function read_savings_model(model = "ME_EX4")
  pydir = joinpath(dirname(pkgdir(Benchmarks)), "Python")
  mx = pyimport("modelx")
  timeit = pyimport("timeit")
  pyimport("openpyxl")
  mx.read_model(joinpath(pydir, "CashValue_$model")).Projection
end
investment_rate(proj::Py) = pyconvert(Array, proj.inv_return_table())[1, :]
ntimesteps(proj::Py) = pyconvert(Int, proj.max_proj_len())
