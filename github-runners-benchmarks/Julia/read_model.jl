using PythonCall: pyimport

python_directory() = joinpath(dirname(@__DIR__), "Python")

"Read a specific `savings` model, such as `SE_EX4` or `ME_EX4`."
function read_savings_model(model = "ME_EX4"; dir = python_directory())
  mx = pyimport("modelx")
  mx.read_model(joinpath(dir, "CashValue_$model")).Projection
end
