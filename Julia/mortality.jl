using MortalityTables
using BenchmarkTools

@inline function npv(qs, r, term = length(qs))
    inforce, result = 1.0, 0.0
    v = 1 / (1 + r)
    v_t = v
    @inbounds @simd for t = 1:min(term, length(qs))
        q = qs[t]
        result += inforce * q * v_t
        inforce = inforce * (1 - q)
        v_t *= v
    end
    return result
end

function mortality1(tbls = [MortalityTables.table(i) for i = 3299:3308])
    issue_ages = 18:50
    durations = 1:25
    term = 29
    total = 0.0
    @inbounds for i in eachindex(tbls), ia in issue_ages, dur in durations
        start_age = ia + dur - 1
        total += @views npv(tbls[i].select[ia][start_age:start_age+term], 0.02)
    end
    return total
end

function run_mortality_benchmarks()
    mort1_result = mortality1()
    b1 = @benchmark mortality1()
    # (result, mean time, median time) named tuple
    return Dict(
        "mortality1" => Dict(
            "result" => mort1_result,
            "mean" => string(mean(b1)),
        ),
    )
end
