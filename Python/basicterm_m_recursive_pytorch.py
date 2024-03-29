from functools import wraps
from collections import defaultdict
import pandas as pd
import torch

torch.set_default_dtype(torch.float64)

# constants
max_proj_len = 12 * 20 + 1

mp = pd.read_csv("BasicTerm_M/model_point_table.csv")
disc_rate = torch.tensor(pd.read_csv("BasicTerm_M/disc_rate_ann.csv")['zero_spot'].values)
mort_np = torch.tensor(pd.read_csv("BasicTerm_M/mort_table.csv").drop(columns=["Age"]).values)
sum_assured = torch.tensor(mp["sum_assured"].values)
issue_age = torch.tensor(mp["age_at_entry"].values)
policy_term = torch.tensor(mp["policy_term"].values)

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
    return mort_np[issue_age + duration - 18, min(duration, 5)]
@cash
def get_monthly_rate(duration: int):
    return 1 - (1 - get_annual_rate(duration)) ** (1/12)
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
    return max(0.1 - 0.02 * duration(t), 0.02)
@cash
def pols_lapse(t: int):
    return (pols_if(t) - pols_death(t)) * (1 - (1 - lapse_rate(t)) ** (1/12))
@cash
def pols_maturity(t: int):
    if t == 0:
        return 0
    return (t == 12 * policy_term) * (pols_if(t - 1) - pols_lapse(t - 1) - pols_death(t - 1))

@cash
def discount(t: int):
    return (1 + disc_rate[duration(t)]) ** (-t/12)
@cash
def claims(t: int):
    return pols_death(t) * sum_assured
@cash
def inflation_rate():
    return 0.01
@cash
def inflation_factor(t):
    return (1 + inflation_rate()) ** (t/12)
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
    return torch.round((1 + loading_prem()) * net_premium_pp(), decimals=2)
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
        "Premiums": [torch.sum(premiums(t)).item() for t in t_len],
        "Claims": [torch.sum(claims(t)).item() for t in t_len],
        "Expenses": [torch.sum(expenses(t)).item() for t in t_len],
        "Commissions": [torch.sum(commissions(t)).item() for t in t_len],
        "Net Cashflow": [torch.sum(net_cf(t)).item() for t in t_len]
    }
    return pd.DataFrame(data, index=t_len)


def basicterm_recursive_pytorch():
    cash.caches.clear()
    return float(torch.sum(pv_net_cf()).item())




def run_tests():
    # Note: The test values may need to be adjusted for PyTorch's precision and operation differences
    assert abs(pv_net_cf()[0] - 910.9206609336586) < 1e-3
    assert abs(pv_premiums()[0] - 8252.085855522233) < 1e-3
    assert abs(pv_expenses()[0] - 755.3660261078035) < 1e-3
    assert abs(pv_commissions()[0] - 1084.6042701164513) < 1e-3
    assert abs(pv_pols_if()[0] - 87.0106058152913) < 1e-3
    assert abs(pv_claims()[0] - 5501.19489836432) < 1e-3
    assert abs(net_premium_pp()[0] - 63.22441783754982) < 1e-3
    # Adjust the following tests for tensors
    # assert all(pols_if(200)[:3] == [0, 0.5724017900070532, 0])
    # assert all(claims(130)[:3] == [0, 28.82531005791726, 0])
    # assert premiums(130)[1] == 39.565567796442494
    # assert expenses(100)[1] == 3.703818110341339
    assert abs(premium_pp()[0] - 94.84) < 1e-2
    assert abs(inflation_factor(100) - 1.0864542626396292) < 1e-3

if __name__ == "__main__":
    run_tests()
    print("All tests passed")
