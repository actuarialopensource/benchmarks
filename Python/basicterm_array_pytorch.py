import torch
import pandas as pd

# Ensure PyTorch uses double precision (64-bit) by default, similar to JAX configuration
torch.set_default_dtype(torch.float64)

# Random uniform distribution in PyTorch
x = torch.rand(1000, dtype=torch.float64)
print(f"{x.dtype=}")  # --> dtype('torch.float64')


mp = pd.read_csv("BasicTerm_M/model_point_table.csv")
disc_rate = torch.tensor(pd.read_csv("BasicTerm_M/disc_rate_ann.csv")["zero_spot"].values)
sum_assured = torch.tensor(mp["sum_assured"].values)
policy_term = torch.tensor(mp["policy_term"].values)
age_at_entry = torch.tensor(mp["age_at_entry"].values)
mort = torch.tensor(pd.read_csv("BasicTerm_M/mort_table.csv").drop(columns=["Age"]).values)

def run(max_proj_len, disc_rate, sum_assured, policy_term, age_at_entry, mort, loading_prem, expense_acq, expense_maint, inflation_rate):
    time_axis = torch.arange(max_proj_len)[:, None]
    duration = time_axis // 12
    discount_factors = (1 + disc_rate[duration]) ** (-time_axis / 12)
    inflation_factor = (1 + inflation_rate) ** (time_axis / 12)
    lapse_rate = torch.maximum(0.1 - 0.02 * duration, torch.tensor(0.02))
    lapse_rate_monthly = 1 - (1 - lapse_rate) ** (1 / 12)
    attained_age = age_at_entry + duration
    annual_mortality = mort[attained_age - 18, torch.minimum(duration, torch.tensor(5, dtype=torch.int64))]
    monthly_mortality = 1 - (1 - annual_mortality) ** (1 / 12)
    pre_pols_if = torch.cat([
        torch.ones((1, monthly_mortality.shape[1])),
        torch.cumprod((1 - lapse_rate_monthly) * (1 - monthly_mortality), dim=0)[:-1],
    ])
    pols_if = (time_axis < (policy_term * 12)) * pre_pols_if
    pols_death = pols_if * monthly_mortality
    claims = sum_assured * pols_death
    pv_claims = torch.sum(claims * discount_factors, dim=0)
    pv_pols_if = torch.sum(pols_if * discount_factors, dim=0)
    net_premium = pv_claims / pv_pols_if
    premium_pp = torch.round((1 + loading_prem) * net_premium, decimals=2)
    premiums = premium_pp * pols_if
    commissions = (duration == 0) * premiums
    expenses = (time_axis == 0) * expense_acq * pols_if + pols_if * expense_maint / 12 * inflation_factor
    pv_premiums = torch.sum(premiums * discount_factors, dim=0)
    pv_expenses = torch.sum(expenses * discount_factors, dim=0)
    pv_commissions = torch.sum(commissions * discount_factors, dim=0)
    pv_net_cf = pv_premiums - pv_claims - pv_expenses - pv_commissions
    return float(pv_net_cf.sum())

def basicterm_array_pytorch():
    # parameters
    max_proj_len = 12 * 20 + 1
    loading_prem = torch.tensor(0.5)
    expense_acq = torch.tensor(300.0)
    expense_maint = torch.tensor(60.0)
    inflation_rate = torch.tensor(0.01)

    return run(
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

if __name__ == "__main__":
    print(basicterm_array_pytorch())


# e2e test
# assert results["net_cf_agg"][100].item() == 97661.8046875
# # integration tests from development
# assert premium_agg[-2].item() == 174528.421875
# assert expenses_agg[-2].item() == 10686.298828125
# assert commissions_agg[11].item() == 751268.375
# assert commissions_agg[-20].item() == 0
# assert claims_agg[-2].item() == 253439.921875
# # unit tests from development
# assert mort_jnp[attained_age - 18, duration][0][0].item() == 0.0006592372665181756
# assert annual_mortality[-1][0].item() == 0.004345308057963848
# assert pols_death[-2][1].item() == 5.005334969609976e-05
# assert pols_death[-1][1].item() == 0
# assert pols_lapse[0][0].item() == 0.008741136640310287
# assert pols_lapse[-2][1].item() == 0.0008985198801383376
# assert pols_lapse[-1][1].item() == 0
# assert lapse_rate[12].item() == 0.07999999821186066
# assert pre_pols_if[-1][1].item() == 0.5332472920417786
# assert pols_if[-1][1].item() == 0
# assert pols_if[-2][1].item() == 0.5341958403587341
# assert pols_maturity[-1][1].item() == 0.5332472920417786
# assert claims[0][0].item() == 34.18231201171875
# assert claims[-2][1].item() == 37.64011764526367
# assert jnp.sum(claims[-1]).item() == 0
# assert discount_factors[11][0].item() == 1
# assert discount_factors[30][0].item() == 0.9831026196479797
# assert pv_claims[0].item() == 5501.505859375
# assert net_premium[0].item() == 63.22805404663086
# assert premiums[-2][1].item() == 32.66129684448242
# assert commissions[1][0].item() == 94.0078353881836
# assert expenses[0][0].item() == 305.0
# assert expenses[-2][1].item() == 3.2564003467559814
