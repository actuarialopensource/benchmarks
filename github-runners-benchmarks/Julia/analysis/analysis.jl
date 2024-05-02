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

# Store results into a dictionary to avoid having to recompute benchmark data every time.
# Empty these dictionaries if you want to regenerate the results.
const TIME_RESULTS = Dict{Model,NamedTuple}()
const MEMORY_RESULTS = Dict{Model,NamedTuple}()
const term_life_model = Ref(LifelibBasiclife(commission_rate = 1.0))
const universal_life_model = Ref(LifelibSavings())

include("time_complexity.jl")
include("memory_complexity.jl")

@info "Running simulation with 10,000,000 model points"
policies = rand(PolicySet, 10_000_000)
CashFlow(universal_life_model[], rand(PolicySet, 1_000), 5) # JIT compilation
# @with SHOW_PROGRESS => true @time CashFlow(universal_life_model[], policies, 150)
open(joinpath(@__DIR__, "large_run.txt"), "w+") do io
  ex = :(CashFlow(universal_life_model[], policies, 150))
  println(io, "julia> ", ex)
  redirect_stdout(io) do
    @eval @time $ex
  end
end
