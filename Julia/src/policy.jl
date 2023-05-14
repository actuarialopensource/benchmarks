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

@enum Claim begin
  CLAIM_DEATH
  CLAIM_LAPSE
  CLAIM_MATURITY
end

age(policy) = policy.age
age(policy, t::Month) = age(policy) + Year(t)

struct PolicySet
  policy::Policy
  count::Float64
end

policy_count(set::PolicySet) = set.count

function policies_from_lifelib(file = "ex4/model_point_table_100K.csv")
  df = read_csv(file)
  policies = PolicySet[]
  for row in eachrow(df)
    sex = row.sex == 'M' ? MALE : FEMALE
    age = Year(row.age_at_entry)
    assured = row.sum_assured
    premium = row.premium_pp
    term = Year(row.policy_term)
    whole_life = term == Year(9999)
    product = getproperty(@__MODULE__, Symbol(:PRODUCT_, row.spec_id))::Product
    policy = Policy(; sex, age, whole_life, assured, premium, term, product)
    push!(policies, PolicySet(policy, row.policy_count))
  end
  policies
end
