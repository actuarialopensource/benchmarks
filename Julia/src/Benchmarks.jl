module Benchmarks

export pv_claims, pv_premiums, pv_commissions, pv_expenses, pv_net_cf, result_pv, result_cf

using DataFrames, CSV, Memoize
using Dates

data_file(file) = joinpath(@__DIR__, "data", joinpath(split(file, '/')...))
function read_csv(file)
  !isabspath(file) && (file = data_file(file))
  CSV.read(file, DataFrame)
end

const final_timestep = Ref{Int}(240)
duration(t::Int) = t ÷ 12

const sum_assured = Ref{Vector{Int}}()
const issue_age = Ref{Vector{Int}}()
const current_policies_term = Ref{Vector{Int}}()

include("mortality.jl")
include("basic_term.jl")

using Accessors: @set
using CSV
using DataFrames
using PythonCall
using Random

include("policy.jl")
include("model.jl")
include("simulation.jl")
include("cashflow.jl")
include("lifelib.jl")

const basic_term_policies = Ref{Vector{PolicySet}}()
const basic_mortality = Ref{BasicMortality}()
set_basic_term_policies!(policies_from_lifelib("basic_term/model_point_table_10K.csv"))

export
  empty_memoization_caches!, set_basic_term_policies!,
  Sex, MALE, FEMALE,
  Policy, policies_from_lifelib,
  PolicySet, policy_count,
  Model, LifelibSavings, investment_rate, brownian_motion, LifelibBasiclife,
  Simulation, SimulationResult, next!, simulate, simulate!, simulation_range,
  CashFlow,
  read_savings_model, ntimesteps, python_directory, use_policies!
end
