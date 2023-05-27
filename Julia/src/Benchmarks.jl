module Benchmarks

export pv_claims, pv_premiums, pv_commissions, pv_expenses, pv_net_cf, result_pv, result_cf

using DataFrames, CSV, Memoize

data_file(file) = joinpath(@__DIR__, "data", joinpath(split(file, '/')...))
read_csv(file) = CSV.read(data_file(file), DataFrame)

const final_timestep = Ref{Int}(240)
duration(t::Int) = t ÷ 12

include("mortality.jl")
include("basic_term.jl")

using Dates
using Accessors: @set
using CSV
using DataFrames

include("policy.jl")
include("model.jl")
include("simulation.jl")

export
  Sex, MALE, FEMALE,
  Policy, policies_from_lifelib,
  PolicySet, policy_count,
  Model, EX4,
  Simulation, SimulationResult, next!, simulate!
end
