import torch
from collections import defaultdict
import pandas as pd
import numpy as np
import torch
from heavylight import LightModel, agg
import timeit
import argparse

# ensure CUDA available
print(f"{torch.cuda.is_available()=}")
# set 64 bit precision
torch.set_default_dtype(torch.float64)
print(f"{torch.get_default_dtype()=}")

disc_rate_ann = pd.read_excel("BasicTerm_ME/disc_rate_ann.xlsx", index_col=0)
mort_table = pd.read_excel("BasicTerm_ME/mort_table.xlsx", index_col=0)
model_point_table = pd.read_excel("BasicTerm_ME/model_point_table.xlsx", index_col=0)
premium_table = pd.read_excel("BasicTerm_ME/premium_table.xlsx", index_col=[0,1])

class ModelPoints:
    def __init__(self, model_point_table: pd.DataFrame, premium_table: pd.DataFrame, size_multiplier: int = 1):
        self.table = model_point_table.merge(premium_table, left_on=["age_at_entry", "policy_term"], right_index=True)
        self.table.sort_values(by="policy_id", inplace=True)
        self.premium_pp = torch.round(torch.tensor(np.tile(self.table["sum_assured"].to_numpy() * self.table["premium_rate"].to_numpy(), size_multiplier)),decimals=2)
        self.duration_mth = torch.tensor(np.tile(self.table["duration_mth"].to_numpy(), size_multiplier))
        self.age_at_entry = torch.tensor(np.tile(self.table["age_at_entry"].to_numpy(), size_multiplier))
        self.sum_assured = torch.tensor(np.tile(self.table["sum_assured"].to_numpy(), size_multiplier))
        self.policy_count = torch.tensor(np.tile(self.table["policy_count"].to_numpy(), size_multiplier))
        self.policy_term = torch.tensor(np.tile(self.table["policy_term"].to_numpy(), size_multiplier))
        self.max_proj_len: int = int(torch.max(12 * self.policy_term - self.duration_mth) + 1)

class Assumptions:
    def __init__(self, disc_rate_ann: pd.DataFrame, mort_table: pd.DataFrame):
        self.disc_rate_ann = torch.tensor(disc_rate_ann["zero_spot"].to_numpy())
        self.mort_table = torch.tensor(mort_table.to_numpy())

    def get_mortality(self, age, duration):
        return self.mort_table[age-18, torch.clamp(duration, max=5)]
    
agg_func = lambda x: float(torch.sum(x))

class TermME(LightModel):
    def __init__(self, mp: ModelPoints, assume: Assumptions):
        super().__init__(agg_function=None)
        self.mp = mp
        self.assume = assume

    def age(self, t):
        return self.mp.age_at_entry + self.duration(t)

    def claim_pp(self, t):
        return self.mp.sum_assured

    def claims(self, t):
        return self.claim_pp(t) * self.pols_death(t)

    def commissions(self, t):
        return (self.duration(t) == 0) * self.premiums(t)

    def disc_factors(self):
        return torch.tensor(list((1 + self.disc_rate_mth()[t])**(-t) for t in range(self.mp.max_proj_len)))

    def discount(self, t: int):
        return (1 + self.assume.disc_rate_ann[t//12]) ** (-t/12)

    def disc_rate_mth(self):
        return torch.tensor(list((1 + self.assume.disc_rate_ann[t//12])**(1/12) - 1 for t in range(self.mp.max_proj_len)))

    def duration(self, t):
        return self.duration_mth(t) // 12

    def duration_mth(self, t):
        if t == 0:
            return self.mp.duration_mth
        else:
            return self.duration_mth(t-1) + 1

    def expense_acq(self):
        return 300

    def expense_maint(self):
        return 60

    def expenses(self, t):
        return self.expense_acq() * self.pols_new_biz(t) \
            + self.pols_if_at(t, "BEF_DECR") * self.expense_maint()/12 * self.inflation_factor(t)

    def inflation_factor(self, t):
        return (1 + self.inflation_rate())**(t/12)

    def inflation_rate(self):
        return 0.01

    def lapse_rate(self, t):
        return torch.clamp(0.1 - 0.02 * self.duration(t), min=0.02)

    def loading_prem(self):
        return 0.5

    def mort_rate(self, t):
        return self.assume.get_mortality(self.age(t), self.duration(t))

    def mort_rate_mth(self, t):
        return 1-(1- self.mort_rate(t))**(1/12)

    def net_cf(self, t):
        return self.premiums(t) - self.claims(t) - self.expenses(t) - self.commissions(t)

    def pols_death(self, t):
        return self.pols_if_at(t, "BEF_DECR") * self.mort_rate_mth(t)

    @agg(agg_func)
    def discounted_net_cf(self, t):
        return torch.sum(self.net_cf(t)) * self.discount(t)

    def pols_if_at(self, t, timing):
        if timing == "BEF_MAT":
            if t == 0:
                return self.pols_if_init()
            else:
                return self.pols_if_at(t-1, "BEF_DECR") - self.pols_lapse(t-1) - self.pols_death(t-1)
        elif timing == "BEF_NB":
            return self.pols_if_at(t, "BEF_MAT") - self.pols_maturity(t)
        elif timing == "BEF_DECR":
            return self.pols_if_at(t, "BEF_NB") + self.pols_new_biz(t)
        else:
            raise ValueError("invalid timing")

    def pols_if_init(self):
        return torch.where(self.duration_mth(0) > 0, self.mp.policy_count, 0)

    def pols_lapse(self, t):
        return (self.pols_if_at(t, "BEF_DECR") - self.pols_death(t)) * (1-(1 - self.lapse_rate(t))**(1/12))

    def pols_maturity(self, t):
        return (self.duration_mth(t) == self.mp.policy_term * 12) * self.pols_if_at(t, "BEF_MAT")

    def pols_new_biz(self, t):
        return torch.where(self.duration_mth(t) == 0, self.mp.policy_count, 0)

    def premiums(self, t):
        return self.mp.premium_pp * self.pols_if_at(t, "BEF_DECR")


def run_recursive_model(model: TermME):
    model.cache_graph._caches = defaultdict(dict)
    model.cache_graph._caches_agg = defaultdict(dict)
    model.RunModel(model.mp.max_proj_len)
    return float(sum(model.cache_agg['discounted_net_cf'].values()))


def time_recursive_GPU(model: TermME):
    model.OptimizeMemoryAndReset()
    start = torch.cuda.Event(enable_timing=True)
    end = torch.cuda.Event(enable_timing=True)
    start.record()
    result = run_recursive_model(model)
    end.record()
    torch.cuda.synchronize()
    return result, start.elapsed_time(end) / 1000

def time_recursive_CPU(model: TermME):
    model.OptimizeMemoryAndReset()
    start = timeit.default_timer()
    result = run_recursive_model(model)
    end = timeit.default_timer()
    return result, end - start

def main():
    parser = argparse.ArgumentParser(description="Term ME model runner")
    parser.add_argument("--disable_cuda", action="store_true", help="Disable CUDA usage")
    parser.add_argument("--multiplier", type=int, default=100, help="Multiplier for model points")
    args = parser.parse_args()

    disable_cuda = args.disable_cuda
    multiplier = args.multiplier

    if not disable_cuda and torch.cuda.is_available():
        device = torch.device('cuda')
    else:
        device = torch.device('cpu')
    print(f"{device=}")

    with device:
        mp = ModelPoints(model_point_table, premium_table)
        mp_multiplied = ModelPoints(model_point_table, premium_table, multiplier)
        assume = Assumptions(disc_rate_ann, mort_table)
        model = TermME(mp, assume)

    if device.type == 'cuda':
        time_recursive = time_recursive_GPU
    else:
        time_recursive = time_recursive_CPU
    run_recursive_model(model) # warm up, generate dependency graph
    model.mp = mp_multiplied
    result, time_in_seconds = time_recursive(model)
    # report results
    print(f"number modelpoints={len(model_point_table) * multiplier:,}")
    print(f"{result=:,}")
    print(f"{time_in_seconds=}")

if __name__ == "__main__":
    main()