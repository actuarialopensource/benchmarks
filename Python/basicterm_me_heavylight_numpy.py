from functools import wraps
from collections import defaultdict
import pandas as pd
import numpy as np
from heavylight.memory_optimized_model import LightModel

disc_rate_ann = pd.read_excel("BasicTerm_ME/disc_rate_ann.xlsx", index_col=0)
mort_table = pd.read_excel("BasicTerm_ME/mort_table.xlsx", index_col=0)
model_point_table = pd.read_excel("BasicTerm_ME/model_point_table.xlsx", index_col=0)
premium_table = pd.read_excel("BasicTerm_ME/premium_table.xlsx", index_col=[0,1])

class ModelPoints:
    def __init__(self, model_point_table: pd.DataFrame, premium_table: pd.DataFrame):
        self.table = model_point_table.merge(premium_table, left_on=["age_at_entry", "policy_term"], right_index=True)
        self.table.sort_values(by="policy_id", inplace=True)
        self.table["premium_pp"] = np.around(self.table["sum_assured"] * self.table["premium_rate"],2)
        self.premium_pp = self.table["premium_pp"].to_numpy()
        self.duration_mth = self.table["duration_mth"].to_numpy()
        self.age_at_entry = self.table["age_at_entry"].to_numpy()
        self.sum_assured = self.table["sum_assured"].to_numpy()
        self.policy_count = self.table["policy_count"].to_numpy()
        self.policy_term = self.table["policy_term"].to_numpy()
        self.max_proj_len: int = np.max(12 * self.policy_term - self.duration_mth) + 1

class Assumptions:
    def __init__(self, disc_rate_ann: pd.DataFrame, mort_table: pd.DataFrame):
        self.disc_rate_ann = disc_rate_ann["zero_spot"].values
        self.mort_table = mort_table.to_numpy()

    def get_mortality(self, age, duration):
        return self.mort_table[age-18, np.minimum(duration, 5)]

class TermME(LightModel):
    def __init__(self, mp: ModelPoints, assume: Assumptions):
        super().__init__()
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
        return np.array(list((1 + self.disc_rate_mth()[t])**(-t) for t in range(self.mp.max_proj_len)))
    
    def discount(self, t: int):
        return (1 + self.assume.disc_rate_ann[t//12]) ** (-t/12)
    
    def disc_rate_mth(self):
        return np.array(list((1 + self.assume.disc_rate_ann[t//12])**(1/12) - 1 for t in range(self.mp.max_proj_len)))
    
    def duration(self, t):
        return self.duration_mth(t) //12
    
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
        return np.maximum(0.1 - 0.02 * self.duration(t), 0.02)
    
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
    
    def pols_if(self, t):
        return self.pols_if_at(t, "BEF_MAT")
    
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
        return np.where(self.duration_mth(0) > 0, self.mp.policy_count, 0)
    
    def pols_lapse(self, t):
        return (self.pols_if_at(t, "BEF_DECR") - self.pols_death(t)) * (1-(1 - self.lapse_rate(t))**(1/12))
    
    def pols_maturity(self, t):
        return (self.duration_mth(t) == self.mp.policy_term * 12) * self.pols_if_at(t, "BEF_MAT")
    
    def pols_new_biz(self, t):
        return np.where(self.duration_mth(t) == 0, self.mp.policy_count, 0)
    
    def premiums(self, t):
        return self.mp.premium_pp * self.pols_if_at(t, "BEF_DECR")
    
mp = ModelPoints(model_point_table, premium_table)
assume = Assumptions(disc_rate_ann, mort_table)
model = TermME(mp, assume)

def basicterm_me_heavylight_numpy():
    model.ResetCache()
    tot = sum(np.sum(model.premiums(t) - model.claims(t) - model.expenses(t) - model.commissions(t)) \
              * model.discount(t) for t in range(model.mp.max_proj_len))
    return tot

if __name__ == "__main__":
     print(basicterm_me_heavylight_numpy())
