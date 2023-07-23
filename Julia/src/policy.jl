@enum Sex MALE FEMALE

@enum PremiumType PREMIUM_SINGLE PREMIUM_LEVEL

struct Product
  premium_type::PremiumType
  surrender_charge::Union{Nothing, Int}
  load_premium_rate::Float64
end

function surrender_charge(product::Product, time::Month, type::Int)
  t = Dates.value(time)
  t > 10 && return 0.0
  type == 1 && return max(0.1 - 0.01t, 0)
  type == 2 && return max(0.08 - 0.01t, 0)
  type == 3 && return max(0.05 - 0.01t, 0)
  error("Expected surrender charge type to be an integer index between 1 and 3")
end

const PRODUCT_A = Product(PREMIUM_SINGLE, nothing, 0.0)
const PRODUCT_B = Product(PREMIUM_SINGLE, 1, 0.0)
const PRODUCT_C = Product(PREMIUM_LEVEL, nothing, 0.1)
const PRODUCT_D = Product(PREMIUM_LEVEL, 3, 0.05)

"""
Policy held with a corresponding account value.
"""
Base.@kwdef struct Policy
  sex::Sex = MALE
  age::Year = Year(20)
  "Whether the policy should last as long as its beneficiary."
  whole_life::Bool = false
  "Sum assured by the policy."
  assured::Float64 = 500_000
  "Premium for the policy."
  premium::Float64 = 450_000
  "Month (after the start of the simulation) the contract has been issued."
  issued_at::Month = Month(0)
  term::Year = Year(10)
  product::Product = PRODUCT_A
  account_value::Float64 = 0.0
end

function Random.rand(rng::AbstractRNG, ::Random.SamplerType{Policy})
  assured = rand(rng, 300_000:700_000)
  # It seems like lifelib doesn't really handle policies with non-zero `issued_at`
  # values well when setting them via `use_policies!`. Might require adjusting
  # other parameters such as investment rates or something.
  issued_at = Month(0)
  # issued_at = Month(rand(rng, 0:120))
  year_issued_at = Dates.value(issued_at) ÷ 12
  product = rand(rng, (PRODUCT_A, PRODUCT_B, PRODUCT_C, PRODUCT_D))
  whole_life = product in (PRODUCT_C, PRODUCT_D)
  Policy(rand(rng, (MALE, FEMALE)), Year(rand(rng, 18:70)), whole_life, assured, assured - rand(rng, 10_000:100_000), issued_at, Year(year_issued_at + rand(rng, 5:20)), product, 0.0)
end

@enum Claim begin
  CLAIM_DEATH
  CLAIM_LAPSE
  CLAIM_MATURITY
end

age(policy) = policy.age
age(policy, t::Month) = age(policy) + Year(t)

"""
Aggregation of a specific type of policy among many policy holders.

The account for universal life models is therefore also unique among all policy holders, amounting to a total of `set.policy.account_value * policy_count(set)`
"""
struct PolicySet
  policy::Policy
  count::Float64
end

Base.rand(rng::AbstractRNG, ::Random.SamplerType{PolicySet}) = PolicySet(rand(rng, Policy), rand(1.0:0.1:1000.0))

policy_count(set::PolicySet) = set.count

"""
Import policies from CSV files compatible with the `lifelib` model.
"""
function policies_from_lifelib(file::AbstractString = "savings/model_point_table_100K.csv")
  df = read_csv(file)
  policies = PolicySet[]
  for row in eachrow(df)
    sex = row.sex == "M" ? MALE : FEMALE
    age = Year(row.age_at_entry)
    assured = row.sum_assured
    premium = get(row, :premium_pp, 0.0)
    term = Year(row.policy_term)
    product = getproperty(@__MODULE__, Symbol(:PRODUCT_, get(row, :spec_id, :A)))::Product
    whole_life = year == Year(9999) || product in (PRODUCT_C, PRODUCT_D)
    policy = Policy(; sex, age, whole_life, assured, premium, term, product, issued_at = -Month(get(row, :duration_mth, 0)))
    push!(policies, PolicySet(policy, row.policy_count))
  end
  policies
end

"""
Import the current policy sets (model points) from a projection model `proj`.
"""
function policies_from_lifelib(proj::Py)
  file = tempname()
  open(file, "w") do io
    println(io, "policy_id,spec_id,age_at_entry,sex,policy_term,policy_count,sum_assured,duration_mth,premium_pp,av_pp_init")
    for (i, row) in enumerate(proj.model_point_table.values)
      print(io, i, ',')
      data = pyconvert(Tuple, row)
      # Skip accum_prem_init_pp.
      data = data[1:(end - 1)]
      println(io, join(data, ','))
    end
    println(io)
  end
  policies_from_lifelib(file)
end

function to_row(policy::PolicySet)
  (; policy, count) = policy
  spec_index = findfirst(==(policy.product), [PRODUCT_A, PRODUCT_B, PRODUCT_C, PRODUCT_D])::Int
  spec_id = ('A', 'B', 'C', 'D')[spec_index]
  sex = policy.sex == MALE ? 'M' : 'F'
  (; spec_id, age_at_entry = Dates.value(policy.age), sex, policy_term = Dates.value(policy.term), policy_count = count, sum_assured = policy.assured, duration_mth = -Dates.value(policy.issued_at), premium_pp = policy.premium, av_pp_init = 0, accum_prem_init_pp = 0)
end

function to_dataframe(policies)
  df = DataFrame(
    :spec_id => Char[],
    :age_at_entry => Int[],
    :sex => Char[],
    :policy_term => Int[],
    :policy_count => Float64[],
    :sum_assured => Int[],
    :duration_mth => Int[],
    :premium_pp => Int[],
    :av_pp_init => Int[],
    :accum_prem_init_pp => Int[],
  )
  for policy in policies
    push!(df, to_row(policy))
  end
  df
end

function to_csv(policies, file = tempname())
  CSV.write(file, to_dataframe(policies))
  file
end
