const zero_spot = read_csv("basic_term/disc_rate_ann.csv")[:, :zero_spot]
const inflation_rate = 0.01
const expense_acq = 300
const expense_maint = 60
const loading_prem = 0.50
const projection_length = 20 * 12

function recompute_globals!()
    sets = basic_term_policies[]
    policies = getproperty.(sets, :policy)
    sum_assured[] = getproperty.(policies, :assured)
    issue_age[] = Dates.value.(getproperty.(policies, :age))
    current_policies_term[] = Dates.value.(getproperty.(policies, :term)) .* Int.(policy_count.(sets))
    basic_mortality[] = BasicMortality()
    empty_memoization_caches!()
end

function empty_memoization_caches!()
    empty!(cache_policies_inforce)
    empty!(cache_premiums_pp)
    empty!(cache_monthly_basic_mortality)
    nothing
end

function set_basic_term_policies!(policies)
    basic_term_policies[] = policies
    recompute_globals!()
end

npoints() = length(issue_age[])

age(t::Int) = age_at_entry() .+ duration(t)
age_at_entry() = issue_age[]
claim_pp(t::Int) = sum_assured[]
claims(t::Int) = claim_pp(t) .* policies_death(t)
commissions(t::Int) = duration(t) == 0 ? premiums(t) : 0.0
disc_factors() = [(1 + disc_rate_mth(t))^(-t) for t in final_timestep[]]
disc_rate_mth(t::Int)::Float64 = (1 + disc_rate_ann(duration(t)))^(1/12) - 1
disc_rate_ann(t::Int)::Float64 = 0.05
expenses(t::Int) = policies_inforce(t) .* ((t == 0 ? expense_acq : 0.0) .+ (expense_maint / 12) .* inflation_factor(t))
inflation_factor(t::Int) = (1 .+ inflation_rate).^(t/12)
disc_factor(t) = (1 + zero_spot[duration(t)+1])^(-t/12)
pv_claims() = foldl((res, t) -> (res .+= claims(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_commissions() = foldl((res, t) -> (res .+= commissions(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_expenses() = foldl((res, t) -> (res .+= expenses(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_pols_if() = foldl((res, t) -> (res .+= policies_inforce(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))
pv_premiums() = foldl((res, t) -> (res .+= premiums(t) .* disc_factor(t)), 0:final_timestep[]; init = zeros(Float64, npoints()))

net_premium_pp() = pv_claims() ./ pv_pols_if()
const cache_premiums_pp = Dict{Tuple{},Vector{Float64}}()
@memoize Returns(cache_premiums_pp)() premium_pp() = round.((1 .+ loading_prem) .* net_premium_pp(); digits = 2)
premiums(t::Int) = premium_pp() .* policies_inforce(t)
pv_net_cf() = pv_premiums() .- pv_claims() .- pv_expenses() .- pv_commissions()

net_cf(t::Int) = premiums(t) .- claims(t) .- expenses(t) .- commissions(t)

function result_cf()
    data = Dict(
        "Premiums" => [sum(premiums(t)) for t in 0:final_timestep[]],
        "Claims" => [sum(claims(t)) for t in 0:final_timestep[]],
        "Expenses" => [sum(expenses(t)) for t in 0:final_timestep[]],
        "Commissions" => [sum(commissions(t)) for t in 0:final_timestep[]],
        "Net Cashflow" => [sum(net_cf(t)) for t in 0:final_timestep[]]
    )
    return DataFrame(data)
end

function result_pv()
    cols = "PV " .* ["Premiums", "Claims", "Expenses", "Commissions", "Net Cashflow"]
    pvs = [pv_premiums(), pv_claims(), pv_expenses(), pv_commissions(), pv_net_cf()]

    return DataFrame(Dict(
            cols .=> pvs,
        ))
end
