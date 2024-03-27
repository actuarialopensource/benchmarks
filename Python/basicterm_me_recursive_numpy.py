from functools import wraps
from collections import defaultdict
import pandas as pd
import numpy as np

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

disc_rate_ann = pd.read_excel("BasicTerm_ME/disc_rate_ann.xlsx", index_col=0)
mort_table = pd.read_excel("BasicTerm_ME/mort_table.xlsx", index_col=0)
model_point_table = pd.read_excel("BasicTerm_ME/model_point_table.xlsx", index_col=0)
premium_table = pd.read_excel("BasicTerm_ME/premium_table.xlsx", index_col=[0,1])

class ModelPoints:
    def __init__(self, model_point_table: pd.DataFrame, premium_table: pd.DataFrame):
        self.table = model_point_table.merge(premium_table, left_on=["age_at_entry", "policy_term"], right_index=True)
        self.table.sort_values(by="policy_id", inplace=True)
        self.table["premium_pp"] = np.around(self.table["sum_assured"] * self.table["premium_rate"],2)
        self.premium_pp = self.table["premium_pp"].values
        self.duration_mth = self.table["duration_mth"].values
        self.age_at_entry = self.table["age_at_entry"].values
        self.sum_assured = self.table["sum_assured"].values
        self.policy_count = self.table["policy_count"].values
        self.policy_term = self.table["policy_term"].values

class Assumptions:
    def __init__(self, disc_rate_ann: pd.DataFrame, mort_table: pd.DataFrame):
        self.disc_rate_ann = disc_rate_ann["zero_spot"].values
        self.mort_table = mort_table.to_numpy()

    def get_mortality(self, age, duration):
        return self.mort_table[age-18, np.minimum(duration, 5)]

mp = ModelPoints(model_point_table, premium_table)
assume = Assumptions(disc_rate_ann, mort_table)

@cash
def age(t):
    return mp.age_at_entry + duration(t)

@cash
def claim_pp(t):
    return mp.sum_assured

@cash
def claims(t):
    return claim_pp(t) * pols_death(t)

@cash
def commissions(t):
    return (duration(t) == 0) * premiums(t)

@cash
def disc_factors():
    return np.array(list((1 + disc_rate_mth()[t])**(-t) for t in range(max_proj_len())))

@cash
def discount(t: int):
    return (1 + assume.disc_rate_ann[t//12]) ** (-t/12)

@cash
def disc_rate_mth():
    return np.array(list((1 + assume.disc_rate_ann[t//12])**(1/12) - 1 for t in range(max_proj_len())))

@cash
def duration(t):
    return duration_mth(t) //12

@cash
def duration_mth(t):
    if t == 0:
        return mp.duration_mth
    else:
        return duration_mth(t-1) + 1

@cash
def expense_acq():
    return 300

@cash
def expense_maint():
    return 60

@cash
def expenses(t):
    return expense_acq() * pols_new_biz(t) \
        + pols_if_at(t, "BEF_DECR") * expense_maint()/12 * inflation_factor(t)

@cash
def inflation_factor(t):
    return (1 + inflation_rate())**(t/12)

@cash
def inflation_rate():
    return 0.01

@cash
def lapse_rate(t):
    return np.maximum(0.1 - 0.02 * duration(t), 0.02)

@cash
def loading_prem():
    return 0.5

@cash
def max_proj_len():
    return max(proj_len())

@cash
def model_point():
    return model_point_table

@cash
def mort_rate(t):
    return assume.get_mortality(age(t), duration(t))

@cash
def mort_rate_mth(t):
    return 1-(1- mort_rate(t))**(1/12)

@cash
def net_cf(t):
    return premiums(t) - claims(t) - expenses(t) - commissions(t)

@cash
def pols_death(t):
    return pols_if_at(t, "BEF_DECR") * mort_rate_mth(t)

@cash
def pols_if(t):
    return pols_if_at(t, "BEF_MAT")

@cash
def pols_if_at(t, timing):
    if timing == "BEF_MAT":
        if t == 0:
            return pols_if_init()
        else:
            return pols_if_at(t-1, "BEF_DECR") - pols_lapse(t-1) - pols_death(t-1)
    elif timing == "BEF_NB":
        return pols_if_at(t, "BEF_MAT") - pols_maturity(t)
    elif timing == "BEF_DECR":
        return pols_if_at(t, "BEF_NB") + pols_new_biz(t)
    else:
        raise ValueError("invalid timing")

@cash
def pols_if_init():
    return np.where(duration_mth(0) > 0, mp.policy_count, 0)

@cash
def pols_lapse(t):
    return (pols_if_at(t, "BEF_DECR") - pols_death(t)) * (1-(1 - lapse_rate(t))**(1/12))

@cash
def pols_maturity(t):
    return (duration_mth(t) == mp.policy_term * 12) * pols_if_at(t, "BEF_MAT")

@cash
def pols_new_biz(t):
    return np.where(duration_mth(t) == 0, mp.policy_count, 0)

@cash
def premiums(t):
    return mp.premium_pp * pols_if_at(t, "BEF_DECR")

@cash
def proj_len():
    return np.maximum(12 * mp.policy_term - duration_mth(0) + 1, 0)

@cash
def pv_claims():
    return sum(claims(t) * discount(t) for t in range(max_proj_len()))

@cash
def pv_commissions():
    return sum(commissions(t) * discount(t) for t in range(max_proj_len()))

@cash
def pv_expenses():
    return sum(expenses(t) * discount(t) for t in range(max_proj_len()))

@cash
def pv_net_cf():
    return pv_premiums() - pv_claims() - pv_expenses() - pv_commissions()

@cash
def pv_pols_if():
    return sum(pols_if_at(t, "BEF_DECR") * discount(t) for t in range(max_proj_len()))

@cash
def pv_premiums():
    return sum(premiums(t) * discount(t) for t in range(max_proj_len()))

@cash
def result_cf():
    t_len = range(max_proj_len())

    data = {
        "Premiums": [sum(premiums(t)) for t in t_len],
        "Claims": [sum(claims(t)) for t in t_len],
        "Expenses": [sum(expenses(t)) for t in t_len],
        "Commissions": [sum(commissions(t)) for t in t_len],
        "Net Cashflow": [sum(net_cf(t)) for t in t_len]
    }

    return pd.DataFrame(data, index=t_len)


def result_pols():
    t_len = range(max_proj_len())

    data = {
        "pols_if": [sum(pols_if(t)) for t in t_len],
        "pols_maturity": [sum(pols_maturity(t)) for t in t_len],
        "pols_new_biz": [sum(pols_new_biz(t)) for t in t_len],
        "pols_death": [sum(pols_death(t)) for t in t_len],
        "pols_lapse": [sum(pols_lapse(t)) for t in t_len]
    }

    return pd.DataFrame(data, index=t_len)


def basicterm_me_recursive_numpy():
    cash.reset()
    return float(np.sum(pv_net_cf()))

if __name__ == "__main__":
    cash.reset()
    print(basicterm_me_recursive_numpy())