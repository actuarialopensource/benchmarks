module Benchmarks

export pv_claims, pv_premiums, pv_commissions, pv_expenses, pv_net_cf, result_pv, result_cf

using DataFrames, CSV, Memoize

data_file(file) = joinpath(dirname(dirname(@__DIR__)), "Python", "BasicTerm_M", file)
read_csv(file) = CSV.read(data_file(file), DataFrame)

const final_timestep = Ref{Int}(240)
duration(t::Int) = t ÷ 12

include("mortality.jl")
include("basic_term.jl")

end
