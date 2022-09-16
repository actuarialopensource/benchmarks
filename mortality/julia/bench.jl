using MortalityTables
using BenchmarkTools

function runner()
    tbls = [MortalityTables.table(i) for i in 3299:3308];
    issue_ages = 18:50
    durations = 1:25
    timesteps = 0:29
    q = [
        tbl.select[issue_age][issue_age+(duration-1) + timestep]
        for timestep in timesteps, (tbl, issue_age, duration) in vec(collect(Iterators.product(tbls, issue_ages, durations)))
    ]
    npx = [1; cumprod(1 .- q[begin:end-1, :], dims=1)]
    v = 1/1.02
    v_eoy = v .^ (1 .+ timesteps) # this broadcasts
    unit_claims_discounted = npx .* q .* v_eoy
    sum(unit_claims_discounted)
end

@assert runner() == 1904.486552663679

b = @benchmark runner()

print("mean time: ", mean(b), "\nmedian time: ", median(b), "\nmemory: ", b.memory)
