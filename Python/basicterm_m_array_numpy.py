import numpy as np
import pandas as pd

# Read data using pandas
mp = pd.read_csv("BasicTerm_M/model_point_table.csv")
disc_rate = np.array(pd.read_csv("BasicTerm_M/disc_rate_ann.csv")["zero_spot"].values, dtype=np.float64)
sum_assured = np.array(mp["sum_assured"].values, dtype=np.float64)
policy_term = np.array(mp["policy_term"].values, dtype=np.int64)
age_at_entry = np.array(mp["age_at_entry"].values, dtype=np.int64)
mort = np.array(pd.read_csv("BasicTerm_M/mort_table.csv").drop(columns=["Age"]).values, dtype=np.float64)

def run(max_proj_len, disc_rate, sum_assured, policy_term, age_at_entry, mort, loading_prem, expense_acq, expense_maint, inflation_rate):
    time_axis = np.arange(max_proj_len)[:, None]
    duration = time_axis // 12
    discount_factors = np.power(1 + disc_rate[duration], -time_axis / 12)
    inflation_factor = np.power(1 + inflation_rate, time_axis / 12)
    lapse_rate = np.maximum(0.1 - 0.02 * duration, 0.02)
    lapse_rate_monthly = 1 - np.power(1 - lapse_rate, 1 / 12)
    attained_age = age_at_entry + duration
    annual_mortality = mort[attained_age - 18, np.minimum(duration, 5)]
    monthly_mortality = 1 - np.power(1 - annual_mortality, 1 / 12)
    pre_pols_if = np.vstack([
        np.ones((1, monthly_mortality.shape[1])),
        np.cumprod((1 - lapse_rate_monthly) * (1 - monthly_mortality), axis=0)[:-1],
    ])
    pols_if = (time_axis < (policy_term * 12)) * pre_pols_if
    pols_death = pols_if * monthly_mortality
    claims = sum_assured * pols_death
    pv_claims = np.sum(claims * discount_factors, axis=0)
    pv_pols_if = np.sum(pols_if * discount_factors, axis=0)
    net_premium = pv_claims / pv_pols_if
    premium_pp = np.round((1 + loading_prem) * net_premium, decimals=2)
    premiums = premium_pp * pols_if
    commissions = (duration == 0) * premiums
    expenses = (time_axis == 0) * expense_acq * pols_if + pols_if * expense_maint / 12 * inflation_factor
    pv_premiums = np.sum(premiums * discount_factors, axis=0)
    pv_expenses = np.sum(expenses * discount_factors, axis=0)
    pv_commissions = np.sum(commissions * discount_factors, axis=0)
    pv_net_cf = pv_premiums - pv_claims - pv_expenses - pv_commissions
    return float(pv_net_cf.sum())

def basicterm_array_numpy():
    # parameters
    max_proj_len = 12 * 20 + 1
    loading_prem = 0.5
    expense_acq = 300.0
    expense_maint = 60.0
    inflation_rate = 0.01

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
    print(basicterm_array_numpy())
