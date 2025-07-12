using CSV
using DataFramesMeta
using MortalityTables
using BenchmarkTools
using OhMyThreads
using Metal
using ChunkSplitters
# parameters


# read data


disc_rate_ann = CSV.read("julia-gpu/data/disc_rate_ann.csv", DataFrame)
mortality = let
    df = CSV.read("julia-gpu/data/mort_table.csv", DataFrame)
    rates = Matrix(df[:, 2:end])
    ult = UltimateMortality(rates[:, end], start_age=23)
    sel = SelectMortality(rates, ult, start_age=18)

end
premium_table = let
    df = CSV.read("julia-gpu/data/premium_table.csv", DataFrame)
    df.age_at_entry = identity.(accumulate((prev, cur) -> ismissing(cur) ? prev : cur, df.age_at_entry))
    df
end
model_point_table = let
    df = CSV.read("julia-gpu/data/model_point_table.csv", DataFrame)
    df = innerjoin(df, premium_table, on=[:age_at_entry, :policy_term])

    # compute premium/policy
    df.premium_pp = round.(df.sum_assured .* df.premium_rate; digits=2)

    df
end

proj_len = maximum(12 * model_point_table.policy_term - model_point_table.duration_mth) + 1

struct Policy5{I<:Integer,F<:AbstractFloat}
    id::I
    duration_month::I
    att_age::I
    term::I
    lives::I
    face::I
    premium_per_policy::F
end

Policy = Policy5

policies = map(eachrow(model_point_table)) do r
    Policy(
        r.policy_id,
        r.duration_mth,
        r.age_at_entry,
        r.policy_term,
        r.policy_count,
        r.sum_assured,
        r.premium_pp
    )
end

expense = (
    acquisition=300,
    maintenance=60
)

assumption_set = (; disc_rate_ann, mortality, premium_table, proj_len, expense)

function pol_project_threaded!(out, policy, params)
    # some starting values for the given policy
    dur_month = policy.duration_month
    start_age = policy.att_age + dur_month ÷ 12
    lives = policy.lives
    # get the right mortality vector
    qs = params.mortality[start_age]

    for t in 1:(12*121)
        if lives < 0.0001 || (t + policy.duration_month) > policy.term * 12
            return
        end

        premium = lives * policy.premium_per_policy
        q = qs[start_age+t÷12] # get current mortality
        deaths = lives * (1 - (1 - q)^(1 / 12))
        claims = deaths * policy.face
        commissions = 0.0
        inflation_factor = 1.01^((t - 1) / 12)
        expenses = params.expense.maintenance / 12 * lives * inflation_factor
        if (t + dur_month) == 1
            commissions += premium
            expenses = params.expense.acquisition * lives
        end
        lapse_rate = max(0.02, 0.1 - 0.02 * (t ÷ 12))
        lapses = (1 - (1 - lapse_rate)^(1 / 12)) * (lives - deaths)
        net_cf = premium - commissions - expenses - claims
        # @show t, lives, net_cf, q, premium, commissions, claims, expenses, deaths, lapses
        lives -= deaths + lapses
        out.net_cf[t] += net_cf
        out.lives[t] += lives
    end
end

function project_all(projection_function, policies, params)
    out = (
        net_cf=zeros(12 * 50),
        lives=zeros(12 * 50)
    )

    tasks = map(chunks(policies; n=Threads.nthreads())) do chunk
        Threads.@spawn begin
            C = (
                net_cf=zeros(12 * 50),
                lives=zeros(12 * 50)
            )
            for pol in chunk
                projection_function(C, pol, params)
            end
            C
        end
    end

    for task ∈ tasks
        C = fetch(task)
        out.net_cf .+= C.net_cf
        out.lives .+= C.lives
    end
    out
end


disc_vector = map(0:length(result.net_cf)-1) do month
    year = month ÷ 12 + 1
    zero_rate = assumption_set.disc_rate_ann[year+1, :zero_spot]
    1 / (1 + zero_rate)^(month / 12)
end


function pol_project_stochastic!(out, policy, params)
    # some starting values for the given policy
    dur_month = policy.duration_month
    start_age = policy.att_age + dur_month ÷ 12
    lives = policy.lives
    inflation_factor = 1.0
    # get the right mortality vector
    qs = params.mortality[start_age]

    # grab the current thread's id to write to results container without conflicting with other threads



    for t in 1:(policy.term*12-policy.duration_month)
        q = 1 - (1 - qs[start_age+t÷12])^(1 / 12)
        deaths = 0
        for _ in 1:lives
            deaths += q > rand()
        end

        lapse_rate = (1 - (1 - max(0.02, 0.1 - 0.02 * (t ÷ 12)))^(1 / 12))
        lapses = 0
        for i in 1:(lives-deaths)
            lapses += lapse_rate > rand()
        end

        premium = lives * policy.premium_per_policy
        commissions = 0.0
        claims = policy.face * deaths
        inflation_factor *= 1.01^(1 / 12)
        expenses = params.expense.maintenance / 12 * lives * inflation_factor
        if (t + dur_month) == 1
            commissions += premium
            expenses = params.expense.acquisition * lives
        end
        net_cf = premium - commissions - expenses - claims
        # @show t, lives, net_cf, q, premium, commissions, claims, expenses, deaths, lapses
        out.net_cf[t] += net_cf

        lives -= deaths + lapses
        lives == 0 && return
        out.lives[t] += lives
    end
end

result = project_all(pol_project_threaded!, repeat(policies, 1), assumption_set)
result2 = project_all(pol_project_stochastic!, repeat(policies, 1), assumption_set)
sum(disc_vector .* result.net_cf)
sum(disc_vector .* result2.net_cf)


@benchmark project_all(pol_project_stochastic!, policies, assumption_set)
@benchmark project_all(pol_project_threaded!, policies, assumption_set)
@benchmark project_all(pol_project_stochastic!, p, $assumption_set) setup = (p = repeat(policies, 1000))

result.lives
result2.lives


@profview project_all(pol_project_threaded!, policies, assumption_set)


# monthly rates

mortality_mth = let
    df = CSV.read("julia-gpu/data/mort_table.csv", DataFrame)
    rates = 1 .- (1 .- Matrix(df[:, 2:end])) .^ (1 / 12)
    ult = UltimateMortality(1 .- (1 .- rates[:, end]) .^ (1 / 12), start_age=23)
    sel = SelectMortality(rates, ult, start_age=18)

end

lapse_rate_mth = let
    v = @. max(0.02, 0.1 - 0.02 * (1:121))
    v = @. (1 - (1 - v)^(1 / 12))
end
assumption_set_mth = (; disc_rate_ann, mortality_mth, premium_table, proj_len, expense, lapse_rate_mth)


function pol_project_threaded_mth!(out, policy, params)
    # some starting values for the given policy
    dur_month = policy.duration_month
    start_age = policy.att_age + dur_month ÷ 12
    lives = policy.lives
    # get the right mortality vector
    qs = params.mortality_mth[start_age]
    inflation_factor = 1.0

    @inbounds for t in 1:(12*121)
        if lives < 0.0001 || (t + policy.duration_month) > policy.term * 12
            return
        end

        premium = lives * policy.premium_per_policy
        q = qs[start_age+t÷12] # get current mortality
        deaths = lives * q
        claims = deaths * policy.face
        commissions = 0.0
        inflation_factor *= 1.01^(1 / 12)
        expenses = params.expense.maintenance / 12 * lives * inflation_factor
        if (t + dur_month) == 1
            commissions += premium
            expenses = params.expense.acquisition * lives
        end
        lapses = params.lapse_rate_mth[t÷12+1] * (lives - deaths)
        net_cf = premium - commissions - expenses - claims
        # @show t, lives, net_cf, q, premium, commissions, claims, expenses, deaths, lapses
        lives -= deaths + lapses
        out.net_cf[t] += net_cf
        out.lives[t] += lives
    end
end

result_mth = project_all(pol_project_threaded_mth!, repeat(policies, 1), assumption_set_mth)

sum(disc_vector .* result.net_cf)

@benchmark project_all(pol_project_threaded_mth!, $policies, $assumption_set_mth)

np = repeat(policies, 1000)
@profview project_all(pol_project_threaded_mth!, np, assumption_set_mth)

length(policies)