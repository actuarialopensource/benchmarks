from Cash import cash, max_proj_len, Cash
import pandas as pd
import numpy as np

mp = pd.read_csv("../Python/BasicTerm_M/model_point_table.csv")
disc_rate = pd.read_csv("../Python/BasicTerm_M/disc_rate_ann.csv")['zero_spot']
mort_np = pd.read_csv("../Python/BasicTerm_M/mort_table.csv").drop(columns=["Age"]).to_numpy()
sum_assured = mp["sum_assured"]
issue_age = mp["age_at_entry"]

@cash
def get_annual_rate(duration: int):
    return mort_np[issue_age + duration - 18, min(duration, 5)]
@cash
def get_monthly_rate(duration: int):
    return 1 - (1 - get_annual_rate(duration))**(1/12)
@cash
def duration(t: int):
    return t // 12
@cash
def pols_death(t: int):
    return pols_if(t) * get_monthly_rate(duration(t))
@cash
def pols_if(t: int):
    if t == 0:
        return np.ones(len(mp))
    return pols_if(t - 1) - pols_lapse(t - 1) - pols_death(t - 1) - pols_maturity(t)

@cash
def lapse_rate(t: int):
    return max(0.1 - 0.02 * duration(t), 0.02)
@cash
def pols_lapse(t: int):
    return (pols_if(t) - pols_death(t)) * (1 - (1 - lapse_rate(t))**(1/12))
@cash
def pols_maturity(t: int):
    return (t == 12 * mp["policy_term"]) * (pols_if(t - 1) - pols_lapse(t - 1) - pols_death(t - 1))

@cash
def summarize_results(cash: Cash) -> pd.DataFrame:
    res = []
    for function_name, cache in cash.caches.items():
        s = pd.Series({k: sum(v) for k, v in cache.items()}, name=function_name)
        res.append(s)
    return pd.concat(res, axis=1)

@cash
def discount(t: int):
    return (1 + disc_rate[duration(t)])**(-t/12)
@cash
def claims(t: int):
    return pols_death(t) * sum_assured
@cash
def inflation_rate():
    return 0.01
@cash
def inflation_factor(t):
    return (1 + inflation_rate())**(t/12)
@cash
def expense_acq():
    return 300
@cash
def expense_maint():
    return 60
@cash
def pv_pols_if():
    return sum(pols_if(t) * discount(t)  for t in range(max_proj_len))
@cash
def pv_claims():
    return sum(claims(t) * discount(t) for t in range(max_proj_len))
@cash
def net_premium_pp():
    return pv_claims() / pv_pols_if()
@cash
def loading_prem():
    return 0.5
@cash
def expenses(t):
    return (t == 0) * expense_acq() * pols_if(t) \
           + pols_if(t) * expense_maint()/12 * inflation_factor(t)
@cash
def premium_pp(t: int):
    return np.around((1 + loading_prem()) * net_premium_pp(), 2)
@cash
def premiums(t):
    return premium_pp(100) * pols_if(t)
@cash
def pv_premiums():
    return sum(premiums(t) * discount(t) for t in range(max_proj_len))
@cash
def pv_expenses():
    return sum(expenses(t) * discount(t) for t in range(max_proj_len))
@cash
def commissions(t):
    return (duration(t) == 0) * premiums(t)
@cash
def pv_commissions():
    return sum(commissions(t) * discount(t) for t in range(max_proj_len))
@cash
def net_cf(t):
    return premiums(t) - claims(t) - expenses(t) - commissions(t)
@cash
def pv_net_cf():
    return pv_premiums() - pv_claims() - pv_expenses() - pv_commissions()
