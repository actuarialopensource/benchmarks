using MortalityTables
using FinanceModels
using LifeContingencies
using FinanceCore
using CSV
using DataFrames
using SumTypes
using ActuaryUtilities

read_csv(file) = CSV.read(data_file(file), DataFrame)
data_file(file) = joinpath(dirname(@__DIR__), "Python", "BasicTerm_M", file)

let
    z = read_csv("disc_rate_ann.csv")[:, :zero_spot]
    # quotes = ZCBYield.(z)
    # fit(Spline.Linear(),quotes,Fit.Bootstrap())
end

mortality = let
    df = read_csv("mort_table.csv")
    issue_age = df[!, :Age]
    ult = UltimateMortality(df[:, end], start_age=first(issue_age))
    sel = SelectMortality(Matrix(df[:, 2:end-1]), ult, start_age=first(issue_age))
    MortalityTable(
        sel,
        ult,
        metadata=TableMetaData(name="SampleTable")
    )
end

# @sum_type Sex begin
#     Male 
#     Female
# end

@enum Sex Male Female

struct TermPol
    issue_age::Int
    sex::Sex
    term::Int
    face::Float64
end

policies = let
    df = read_csv("model_point_table.csv")
    map(eachrow(df)) do r
        TermPol(
            r.age_at_entry,
            r.sex == "M" ? Male : Female,
            r.policy_term,
            r.sum_assured
        )
    end

end

parameters = (
    inflation_rate=0.01,
    expense_acq=300,
    expense_maint=60,
    loading_prem=0.50,
    projection_length=20 * 12,
    mortality=mortality,
    yield_curve=yield,
)

function project!(results, policy, parameters)
    surv = 1.0
    infl = 1.0
    t = 0.0

    ins = Insurance(SingleLife(parameters.mortality.select[policy.issue_age]), parameters.yield_curve, policy.term)
    prem_net = present_value(parameters.yield_curve, 1/12:1/12:policy.term)
    results.expenses[begin] -= parameters.expense_acq

    for timestep in 1:parameters.projection_length
        q = decrement(
            parameters.mortality.select[policy.issue_age],
            policy.issue_age + t,
            policy.issue_age + t + 1 / 12,
            MortalityTables.Uniform()
        )
        claim = -policy.face * q * surv
        prem = prem_net * surv
        expense = -parameters.expense_maint / 12 * infl * surv
        commission = t ≤ 12 ? -prem : 0.0

        results.premiums[timestep] += prem
        results.claims[timestep] += claim
        results.expenses[timestep] += expense
        results.commissions[timestep] += commission
        results.net_cf[timestep] += prem + claim + expense + commission

        infl *= (1 + parameters.inflation_rate / 12)
        t += 1 / 12
        surv *= (1 - q)
        @show infl, t, surv
    end


end



function project_all(policies, params)
    output = (
        premiums=zeros(params.projection_length),
        claims=zeros(params.projection_length),
        expenses=zeros(params.projection_length),
        commissions=zeros(params.projection_length),
        net_cf=zeros(params.projection_length),
    )

    for policy in policies
        project!(output, policy, params)
    end
    output
end

res = project_all(policies[1:1], parameters) |> DataFrame
# pv(parameters.yield_curve,res.net_cf,0:parameters.projection_length ./ 12)
