using LifeSimulator, CairoMakie, BenchmarkTools, PythonCall, Accessors, Dates

images_folder() = joinpath(@__DIR__, "images")

model_string(::LifelibBasiclife) = "basic_life"
model_string(::LifelibSavings) = "universal_life"
model_title(::LifelibBasiclife) = "Term life"
model_title(::LifelibSavings) = "Universal life"
language_used_memoized(::LifelibBasiclife) = "Julia"
language_used_memoized(::LifelibSavings) = "Python"

include("../read_model.jl")
!@isdefined(proj) && (proj = read_savings_model())

const TIME_RESULTS = Dict{Model,NamedTuple}()
const MEMORY_RESULTS = Dict{Model,NamedTuple}()
const term_life_model = Ref(LifelibBasiclife())
const universal_life_model = Ref(LifelibSavings())

include("time_complexity.jl")
include("memory_complexity.jl")

policies = rand(PolicySet, 10_000_000)
CashFlow(Simulation(universal_life_model[], rand(PolicySet, 1_000)), 5) # JIT compilation
# @with SHOW_PROGRESS => true @time CashFlow(Simulation(universal_life_model[], policies), 150)
open(joinpath(@__DIR__, "large_run.txt"), "w+") do io
  ex = :(CashFlow(Simulation(universal_life_model[], policies), 150))
  println(io, "julia> ", ex)
  redirect_stdout(io) do
    @eval @time $ex
  end
end
