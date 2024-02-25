using CSV
using DataFrames
using Tables
using LoopVectorization

# Random uniform distribution in PyTorch

read_csv(file) = CSV.read(data_file(file), DataFrame)
data_file(file) = joinpath(dirname(@__DIR__), "Python", "BasicTerm_M", file)


function project(max_proj_len, disc_rate, sum_assured, policy_term, age_at_entry, mort, loading_prem, expense_acq, expense_maint, inflation_rate)
    time_axis = 0:(max_proj_len-1)
    duration = time_axis .÷ 12
    discount_factors = @. (1 + disc_rate[duration+1])^(-time_axis / 12)
    inflation_factor = @. (1 + inflation_rate)^(time_axis / 12)
    lapse_rate = @. max(0.1 - 0.02 * duration, 0.02)
    lapse_rate_monthly = @. 1 - (1 - lapse_rate)^(1 / 12)

    monthly_mortality = [mort[ia+d-17, min(d + 1, 6)] for ia in age_at_entry, d in duration]
    monthly_mortality .= @turbo @. 1 - (1 - monthly_mortality)^(1 / 12)

    pols_if = let
        m = similar(monthly_mortality)
        for I in CartesianIndices(m)
            i, j = Tuple(I)
            m[i, j] = if j == 1
                1.0
            elseif policy_term[i] * 12 < j
                0.0
            else
                m[i, j-1] * (1 - lapse_rate_monthly[j-1]) * (1 - monthly_mortality[i, j-1])
            end
        end
        m
    end

    claims = @. monthly_mortality * pols_if * sum_assured
    pv_claims = claims * discount_factors
    pv_pols_if = pols_if * discount_factors
    net_premium = pv_claims ./ pv_pols_if
    premium_pp = @. round((1 + loading_prem) * net_premium, digits=2)
    premiums = premium_pp .* pols_if
    commissions = (duration .== 0)' .* premiums
    expenses = @. (expense_maint / 12 * inflation_factor)' * pols_if
    expenses[:, 1] .+= expense_acq
    pv_premiums = premiums * discount_factors
    pv_expenses = expenses * discount_factors
    pv_commissions = commissions * discount_factors
    pv_net_cf = @. pv_premiums - pv_claims - pv_expenses - pv_commissions
    sum(pv_net_cf)
end

function run_basicterm_array_benchmark()
    # parameters
    max_proj_len = 12 * 20 + 1
    loading_prem = 0.5
    expense_acq = 300.0
    expense_maint = 60.0
    inflation_rate = 0.01

    mp = read_csv("model_point_table.csv")
    disc_rate = read_csv("disc_rate_ann.csv").zero_spot
    sum_assured = mp.sum_assured
    policy_term = mp.policy_term
    age_at_entry = mp.age_at_entry
    mort = CSV.read(data_file("mort_table.csv"), Tables.matrix; drop=[1])

    result = return project(
        max_proj_len,
        disc_rate,
        sum_assured,
        policy_term,
        age_at_entry,
        mort,
        loading_prem,
        expense_acq,
        expense_maint,
        inflation_rate,
    )

    b1 = @benchmark return project(
        $max_proj_len,
        $disc_rate,
        $sum_assured,
        $policy_term,
        $age_at_entry,
        $mort,
        $loading_prem,
        $expense_acq,
        $expense_maint,
        $inflation_rate,
    )

    return Dict(
        "Julia basic term array" => Dict(
            "result" => result,
            "minimum time" => string(minimum(b1)),
        ),
    )
end