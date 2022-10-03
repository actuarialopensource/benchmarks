using MortalityTables
using BenchmarkTools

@inline function npv(qs, r, term=length(qs))
    inforce, result = 1.0, 0.0
    v = 1 / (1 + r)
    v_t = v
    @inbounds @simd for t in 1:min(term, length(qs))
        q = qs[t]
        result += inforce * q * v_t
        inforce = inforce * (1 - q)
        v_t *= v
    end
    return result
end

function runner(tbls=[MortalityTables.table(i) for i in 3299:3308])
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

@assert runner() ≈ 1904.486552663679

b = @benchmark runner()

print("mean time: ", mean(b), "\nmedian time: ", median(b), "\nmemory: ", b.memory)
