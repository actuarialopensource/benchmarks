using CacheFlow
using CacheFlow: CacheFlow as cf
using DataFrames: DataFrame
using Test

@testset "CacheFlow.jl" begin
    @test cf.policies_inforce(200)[1:3] == [0.000000, 0.5724017900070532, 0.000000]
    @test cf.claims(130)[1:3] ≈ [0.0, 28.82531005791726, 0.0]
    @test cf.expenses(100)[1:3] == [3.682616858501336, 3.703818110341339, 3.671941182132007]
    @test cf.expenses(0)[1:3] == [305.0,305.0,305.0]

    @test pv_claims()[1:3] ≈ [5501.19489836432, 5956.471604652321, 9190.425784230943]
    @test pv_premiums()[1:3] ≈ [8252.08585552, 8934.76752446, 13785.48441688]
    @test pv_commissions()[1:3] ≈ [1084.60427012, 699.31842569, 1814.20246663]
    @test pv_expenses()[1:3] ≈ [755.36602611, 1097.43049098, 754.73305144]
    @test pv_net_cf()[1:3] ≈ [910.92066093, 1181.54700314, 2026.12311458]

    pvs = result_pv()
    @test isa(pvs, DataFrame)
    cfs = result_cf()
    @test isa(cfs, DataFrame)
end;
