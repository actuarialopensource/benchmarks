using Benchmarks, Dates
using Benchmarks: Benchmarks as B
using DataFrames: DataFrame
using Test

@testset "Benchmarks.jl" begin
    include("basiclife.jl")
    include("savings.jl")
end;
