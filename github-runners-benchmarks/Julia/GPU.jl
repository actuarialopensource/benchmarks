using CUDA
using DataFrames
using XLSX
using BenchmarkTools

# Load assumption data
disc_rate_ann = DataFrame(XLSX.readtable("BasicTerm_ME/disc_rate_ann.xlsx", "Sheet1")...)
mort_table = DataFrame(XLSX.readtable("BasicTerm_ME/mort_table.xlsx", "Sheet1")...)
model_point_table = DataFrame(XLSX.readtable("BasicTerm_ME/model_point_table.xlsx", "Sheet1")...)
premium_table = DataFrame(XLSX.readtable("BasicTerm_ME/premium_table.xlsx", "Sheet1")...)

# Define model point struct
struct ModelPoints
    premium_pp::CuArray{Float64}
    duration_mth::CuArray{Int}
    age_at_entry::CuArray{Int}
    sum_assured::CuArray{Float64}
    policy_count::CuArray{Float64}
    policy_term::CuArray{Int}
    max_proj_len::Int
end

function ModelPoints(model_point_table, premium_table; size_multiplier=1)
    # Join and preprocess model point and premium data
    mp_data = innerjoin(model_point_table, premium_table, on=[:age_at_entry, :policy_term])
    sort!(mp_data, :policy_id)

    # Initialize model point struct
    premium_pp = CuArray(repeat(mp_data.sum_assured .* mp_data.premium_rate, size_multiplier))
    duration_mth = CuArray(repeat(mp_data.duration_mth, size_multiplier))
    age_at_entry = CuArray(repeat(mp_data.age_at_entry, size_multiplier))
    sum_assured = CuArray(repeat(mp_data.sum_assured, size_multiplier))
    policy_count = CuArray(repeat(mp_data.policy_count, size_multiplier))
    policy_term = CuArray(repeat(mp_data.policy_term, size_multiplier))
    max_proj_len = maximum(12 .* policy_term .- duration_mth) + 1

    ModelPoints(premium_pp, duration_mth, age_at_entry, sum_assured, policy_count, policy_term, max_proj_len)
end

# Define assumptions struct
struct Assumptions
    disc_rate_ann::CuArray{Float64}
    mort_table::CuArray{Float64}
    expense_acq::Float64
    expense_maint::Float64
end

function Assumptions(disc_rate_ann, mort_table)
    disc_rate_ann_cu = CuArray(disc_rate_ann.zero_spot)
    mort_table_cu = CuArray(Matrix(mort_table))
    expense_acq = 300.0
    expense_maint = 60.0
    Assumptions(disc_rate_ann_cu, mort_table_cu, expense_acq, expense_maint)
end

# Define projection loop state struct
struct LoopState
    t::Int
    tot::Float64
    pols_lapse_prev::CuArray{Float64}
    pols_death_prev::CuArray{Float64}
    pols_if_at_BEF_DECR_prev::CuArray{Float64}
end

# Define main projection struct
struct TermME
    mp::ModelPoints
    assume::Assumptions
    init_ls::LoopState
end

function TermME(mp, assume)
    init_ls = LoopState(
        0,
        0.0,
        CUDA.zeros(Float64, length(mp.duration_mth)),
        CUDA.zeros(Float64, length(mp.duration_mth)),
        CuArray((mp.duration_mth .> 0) .* mp.policy_count)
    )
    TermME(mp, assume, init_ls)
end

function run_term_ME(tm::TermME)
    function iterative_core(ls, _)
        duration_month_t = tm.mp.duration_mth .+ ls.t
        duration_t = duration_month_t .÷ 12
        age_t = tm.mp.age_at_entry .+ duration_t
        pols_if_init = ls.pols_if_at_BEF_DECR_prev .- ls.pols_lapse_prev .- ls.pols_death_prev
        pols_if_at_BEF_MAT = pols_if_init
        pols_maturity = (duration_month_t .== tm.mp.policy_term .* 12) .* pols_if_at_BEF_MAT
        pols_if_at_BEF_NB = pols_if_at_BEF_MAT .- pols_maturity
        pols_new_biz = (duration_month_t .== 0) .* tm.mp.policy_count
        pols_if_at_BEF_DECR = pols_if_at_BEF_NB .+ pols_new_biz
        mort_rate = tm.assume.mort_table[age_t.-17, min.(duration_t, 5)]
        mort_rate_mth = 1 .- (1 .- mort_rate) .^ (1 / 12)
        pols_death = pols_if_at_BEF_DECR .* mort_rate_mth
        claims = tm.mp.sum_assured .* pols_death
        premiums = tm.mp.premium_pp .* pols_if_at_BEF_DECR
        commissions = (duration_t .== 0) .* premiums
        discount = (1 .+ tm.assume.disc_rate_ann[ls.t.÷12]) .^ (-ls.t ./ 12)
        inflation_factor = (1 + 0.01) .^ (ls.t ./ 12)
        expenses = tm.assume.expense_acq .* pols_new_biz .+ pols_if_at_BEF_DECR .* tm.assume.expense_maint ./ 12 .* inflation_factor
        lapse_rate = max.(0.1 .- 0.02 .* duration_t, 0.02)
        net_cf = premiums .- claims .- expenses .- commissions
        discounted_net_cf = sum(net_cf .* discount)
        nxt_ls = LoopState(
            ls.t + 1,
            ls.tot + discounted_net_cf,
            (pols_if_at_BEF_DECR .- pols_death) .* (1 .- (1 .- lapse_rate) .^ (1 / 12)),
            pols_death,
            pols_if_at_BEF_DECR
        )
        return nxt_ls, nothing
    end

    result, _ = foldl(iterative_core, 1:tm.mp.max_proj_len, init=tm.init_ls)
    result.tot
end

function time_term_ME(mp, assume)
    tm = TermME(mp, assume)
    run_term_ME(tm)  # warmup
    tot = @btime run_term_ME($tm)
    tot, @elapsed run_term_ME(tm)
end

function main(multiplier)
    mp = ModelPoints(model_point_table, premium_table, size_multiplier=multiplier)
    assume = Assumptions(disc_rate_ann, mort_table)
    tot, elapsed = time_term_ME(mp, assume)

    println("CUDA.jl Term ME Model")
    println("Number modelpoints: $(length(mp.duration_mth))")
    println("Total: $tot")
    println("Elapsed time: $elapsed seconds")
end

main(1000)