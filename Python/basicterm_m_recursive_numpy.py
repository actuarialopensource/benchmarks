from functools import wraps
from collections import defaultdict
import pandas as pd
import numpy as np

# constants
max_proj_len = 12 * 20 + 1

mp = pd.read_csv("BasicTerm_M/model_point_table.csv")
disc_rate = np.array(pd.read_csv("BasicTerm_M/disc_rate_ann.csv")['zero_spot'].values, dtype=np.float64)
mort_np = np.array(pd.read_csv("BasicTerm_M/mort_table.csv").drop(columns=["Age"]).values, dtype=np.float64)
sum_assured = np.array(mp["sum_assured"].values, dtype=np.float64)
issue_age = np.array(mp["age_at_entry"].values, dtype=np.int32)
policy_term = np.array(mp["policy_term"].values, dtype=np.int32)

# classes
class Cash:
    def __init__(self):
        self.reset()

    def reset(self):
        self.caches = defaultdict(dict)

    def __call__(self, func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            key = (args, frozenset(kwargs.items()))
            if key not in self.caches[func.__name__]:
                self.caches[func.__name__][key] = func(*args, **kwargs)
            return self.caches[func.__name__][key]

        return wrapper

cash = Cash()

@cash
def get_annual_rate(duration: int):
    return mort_np[issue_age + duration - 18, np.minimum(duration, 5)]
@cash
def get_monthly_rate(duration: int):
    return 1 - np.power((1 - get_annual_rate(duration)), 1/12)
@cash
def duration(t: int):
    return t // 12
@cash
def pols_death(t: int):
    return pols_if(t) * get_monthly_rate(duration(t))
@cash
def pols_if(t: int):
    if t == 0:
        return 1
    return pols_if(t - 1) - pols_lapse(t - 1) - pols_death(t - 1) - pols_maturity(t)

@cash
def lapse_rate(t: int):
    return np.maximum(0.1 - 0.02 * duration(t), 0.02)
@cash
def pols_lapse(t: int):
    return (pols_if(t) - pols_death(t)) * (1 - np.power((1 - lapse_rate(t)), 1/12))
@cash
def pols_maturity(t: int):
    if t == 0:
        return 0
    return (t == 12 * policy_term) * (pols_if(t - 1) - pols_lapse(t - 1) - pols_death(t - 1))

@cash
def discount(t: int):
    return np.power((1 + disc_rate[duration(t)]), (-t/12))
@cash
def claims(t: int):
    return pols_death(t) * sum_assured
@cash
def inflation_rate():
    return 0.01
@cash
def inflation_factor(t):
    return np.power((1 + inflation_rate()), (t/12))
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
def premium_pp():
    return np.round((1 + loading_prem()) * net_premium_pp(), decimals=2)
@cash
def premiums(t):
    return premium_pp() * pols_if(t)
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

@cash
def result_cf():
    t_len = range(max_proj_len)

    data = {
    "Premiums": [np.sum(premiums(t)) for t in t_len],
    "Claims": [np.sum(claims(t)) for t in t_len],
    "Expenses": [np.sum(expenses(t)) for t in t_len],
    "Commissions": [np.sum(commissions(t)) for t in t_len],
    "Net Cashflow": [np.sum(net_cf(t)) for t in t_len]
    }
    return pd.DataFrame(data, index=t_len)

def basicterm_recursive_numpy():
    cash.reset() # Ensure the cache is clear before running calculations
    return float(np.sum(pv_net_cf()))

if __name__ == "__main__":
    print(basicterm_recursive_numpy())
