from collections import defaultdict
from functools import wraps
import pandas as pd
import numpy as np
from heavylight import LightModel

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

disc_rate_ann = np.array(pd.read_excel("./CashValue_ME_EX4/disc_rate_ann.xlsx")["zero_spot"])
disc_rate_arr = np.concatenate([[1], np.cumprod((1+np.repeat(disc_rate_ann, 12)) ** (-1/12))])
mort_table = pd.read_excel("./CashValue_ME_EX4/mort_table.xlsx")
surr_charge_table = pd.read_excel("./CashValue_ME_EX4/surr_charge_table.xlsx")
product_spec_table = pd.read_excel("./CashValue_ME_EX4/product_spec_table.xlsx")
model_point_table = pd.read_csv("./CashValue_ME_EX4/model_point_table_10K.csv")
model_point_table_ext = model_point_table.merge(product_spec_table, on='spec_id')
model_point_moneyness = pd.read_excel("./CashValue_ME_EX4/model_point_moneyness.xlsx")
scen_id = 1
scen_size = 1

@cash
def age(t):
    return age_at_entry() + duration(t)

@cash
def age_at_entry():
    return model_point()["age_at_entry"].values

@cash
def av_at(t, timing):
    if timing == "BEF_MAT":
        return av_pp_at(t, "BEF_PREM") * pols_if_at(t, "BEF_MAT")
    elif timing == "BEF_NB":
        return av_pp_at(t, "BEF_PREM") * pols_if_at(t, "BEF_NB")
    elif timing == "BEF_FEE":
        return av_pp_at(t, "BEF_FEE") * pols_if_at(t, "BEF_DECR")
    else:
        raise ValueError("invalid timing")
    
@cash
def av_change(t):
    return av_at(t+1, 'BEF_MAT') - av_at(t, 'BEF_MAT')

@cash
def av_pp_at(t, timing):
    if timing == "BEF_PREM":
        if t == 0:
            return av_pp_init()
        else:
            return av_pp_at(t-1, "BEF_INV") + inv_income_pp(t-1)
    elif timing == "BEF_FEE":
        return av_pp_at(t, "BEF_PREM") + prem_to_av_pp(t)
    elif timing == "BEF_INV":
        return av_pp_at(t, "BEF_FEE") - maint_fee_pp(t) - coi_pp(t)
    elif timing == "MID_MTH":
        return av_pp_at(t, "BEF_INV") + 0.5 * inv_income_pp(t)
    else:
        raise ValueError("invalid timing")
    
@cash
def av_pp_init():
    return model_point()["av_pp_init"].values

@cash
def claim_net_pp(t, kind):
    if kind == "DEATH":
        return claim_pp(t, "DEATH") - av_pp_at(t, "MID_MTH")
    elif kind == "LAPSE":
        return 0
    elif kind == "MATURITY":
        return claim_pp(t, "MATURITY") - av_pp_at(t, "BEF_PREM")
    else:
        raise ValueError("invalid kind")
    
@cash
def claim_pp(t, kind):
    if kind == "DEATH":
        return np.maximum(sum_assured(), av_pp_at(t, "MID_MTH"))
    elif kind == "LAPSE":
        return av_pp_at(t, "MID_MTH")
    elif kind == "MATURITY":
        return np.maximum(sum_assured(), av_pp_at(t, "BEF_PREM"))
    else:
        raise ValueError("invalid kind")

@cash
def claims(t, kind=None):
    if kind == "DEATH":
        return claim_pp(t, "DEATH") * pols_death(t)
    elif kind == "LAPSE":
        return claims_from_av(t, "LAPSE") - surr_charge(t)
    elif kind == "MATURITY":
        return claim_pp(t, "MATURITY") * pols_maturity(t)
    elif kind is None:
        return sum(claims(t, k) for k in ["DEATH", "LAPSE", "MATURITY"])
    else:
        raise ValueError("invalid kind")

@cash
def claims_from_av(t, kind):
    if kind == "DEATH":
        return av_pp_at(t, "MID_MTH") * pols_death(t)
    elif kind == "LAPSE":
        return av_pp_at(t, "MID_MTH") * pols_lapse(t)
    elif kind == "MATURITY":
        return av_pp_at(t, "BEF_PREM") * pols_maturity(t)
    else:
        raise ValueError("invalid kind")

@cash
def claims_over_av(t, kind):
    return claims(t, kind) - claims_from_av(t, kind)

@cash
def coi(t):
    return coi_pp(t) * pols_if_at(t, "BEF_DECR")

@cash
def coi_pp(t):
    return coi_rate(t) * net_amt_at_risk(t)

@cash
def coi_rate(t):
    return 0    #1.1 * mort_rate_mth(t)

@cash
def commissions(t):
    return 0.05 * premiums(t)

@cash
def disc_factors():
    return disc_rate_arr[:max_proj_len()]

@cash
def duration(t):
    return duration_mth(t) // 12

@cash
def duration_mth(t):
    if t == 0:
        return model_point()['duration_mth'].values
    else:
        return duration_mth(t-1) + 1

@cash
def expense_acq():
    return 5000

@cash
def expense_maint():
    return 500

@cash
def expenses(t):
    return expense_acq() * pols_new_biz(t) \
        + pols_if_at(t, "BEF_DECR") * expense_maint()/12 * inflation_factor(t)

@cash
def has_surr_charge():
    return model_point()['has_surr_charge'].values

@cash
def inflation_factor(t):
    return (1 + inflation_rate())**(t/12)

@cash
def inflation_rate():
    return 0.01

@cash
def inv_income(t):
    return (inv_income_pp(t) * pols_if_at(t+1, "BEF_MAT")
            + 0.5 * inv_income_pp(t) * (pols_death(t) + pols_lapse(t)))

@cash
def inv_income_pp(t):
    return inv_return_mth(t) * av_pp_at(t, "BEF_INV")

@cash
def inv_return_mth(t):
    return inv_return_table()[:, t]

@cash
def inv_return_table():
    mu = 0.02
    sigma = 0.03
    dt = 1/12

    return np.tile(np.exp(
        (mu - 0.5 * sigma**2) * dt + sigma * dt**0.5 * std_norm_rand()) - 1,
        (point_size(), 1))

@cash
def is_wl():
    return model_point()['is_wl'].values

@cash
def lapse_rate(t):
    return 0

@cash
def load_prem_rate():
    return model_point()['load_prem_rate'].values

@cash
def maint_fee(t):
    return maint_fee_pp(t) * pols_if_at(t, "BEF_DECR")

@cash
def maint_fee_pp(t):
    return maint_fee_rate() * av_pp_at(t, "BEF_FEE")

@cash
def maint_fee_rate():
    return 0    # 0.01 / 12

@cash
def margin_expense(t):
    return (load_prem_rate()* premium_pp(t) * pols_if_at(t, "BEF_DECR")
            + surr_charge(t)
            + maint_fee(t)
            - commissions(t)
            - expenses(t))

@cash
def margin_mortality(t):
    return coi(t) - claims_over_av(t, 'DEATH')

@cash
def max_proj_len():
    return max(proj_len())

@cash
def model_point():
    mps = model_point_table_ext

    idx = pd.MultiIndex.from_product(
            [mps.index, scen_index()],
            names = mps.index.names + scen_index().names
            )

    res = pd.DataFrame(
            np.repeat(mps.values, len(scen_index()), axis=0),
            index=idx,
            columns=mps.columns
        )

    return res.astype(mps.dtypes)

@cash
def mort_rate(t):
    return np.zeros(len(model_point().index))

@cash
def mort_rate_mth(t):
    return 1-(1- mort_rate(t))**(1/12)

@cash
def mort_table_last_age():
    return 102 # original implementation contained a bug, hard coding for now

@cash
def mort_table_reindexed():
    result = []
    for col in mort_table.columns:
        df = mort_table[[col]]
        df = df.assign(Duration=int(col)).set_index('Duration', append=True)[col]
        result.append(df)

    return pd.concat(result)

@cash
def net_amt_at_risk(t):
    return np.maximum(sum_assured() - av_pp_at(t, 'BEF_FEE'), 0)

@cash
def net_cf(t):
    return (premiums(t)
            + inv_income(t) - claims(t) - expenses(t) - commissions(t) - av_change(t))

@cash
def policy_term():
    return (is_wl() * (mort_table_last_age() - age_at_entry()) 
            + (is_wl() == False) * model_point()["policy_term"].values)

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
    return model_point()["policy_count"].where(duration_mth(0) > 0, other=0).values

@cash
def pols_lapse(t):
    return (pols_if_at(t, "BEF_DECR") - pols_death(t)) * (1-(1 - lapse_rate(t))**(1/12))

@cash
def pols_maturity(t):
    return (duration_mth(t) == policy_term() * 12) * pols_if_at(t, "BEF_MAT")

@cash
def pols_new_biz(t):
    return model_point()['policy_count'].values * (duration_mth(t) == 0)

@cash
def prem_to_av(t):
    return  prem_to_av_pp(t) * pols_if_at(t, "BEF_DECR")

@cash
def prem_to_av_pp(t):
    return (1 - load_prem_rate()) * premium_pp(t)

@cash
def premium_pp(t):
    return model_point()['premium_pp'].values * ((premium_type() == 'SINGLE') & (duration_mth(t) == 0) |
                                                 (premium_type() == 'LEVEL') & (duration_mth(t) < 12 * policy_term()))

@cash
def premium_type():
    return model_point()['premium_type'].values

@cash
def premiums(t):
    return premium_pp(t) * pols_if_at(t, "BEF_DECR")

@cash
def proj_len():
    return np.maximum(12 * policy_term() - duration_mth(0) + 1, 0)

@cash
def pv_av_change():
    return sum(av_change(t) * disc_rate_arr[t] for t in range(max_proj_len()))

@cash
def pv_claims(kind=None):
    return sum(claims(t, kind) * disc_rate_arr[t] for t in range(max_proj_len()))

@cash
def pv_commissions():
    return sum(commissions(t) * disc_rate_arr[t] for t in range(max_proj_len()))

@cash
def pv_expenses():
    return sum(expenses(t) * disc_rate_arr[t] for t in range(max_proj_len()))

@cash
def pv_inv_income():
    return sum(inv_income(t) * disc_rate_arr[t] for t in range(max_proj_len()))

@cash
def pv_pols_if():
    return sum(pols_if_at(t, "BEF_DECR") for t in range(max_proj_len()))

@cash
def pv_premiums():
    return sum(premiums(t) * disc_rate_arr[t] for t in range(max_proj_len()))

@cash
def pv_net_cf():
    return (pv_premiums() 
            + pv_inv_income() 
            - pv_claims() 
            - pv_expenses() 
            - pv_commissions() 
            - pv_av_change())

@cash
def result_pv():
    data = {
            "Premiums": pv_premiums(), 
            "Death": pv_claims("DEATH"),
            "Surrender": pv_claims("LAPSE"),
            "Maturity": pv_claims("MATURITY"),
            "Expenses": pv_expenses(), 
            "Commissions": pv_commissions(), 
            "Investment Income": pv_inv_income(),
            "Change in AV": pv_av_change(),
            "Net Cashflow": pv_net_cf()
        }
    return pd.DataFrame(data, index=model_point().index)

@cash
def scen_index():
    return pd.Index(range(1, scen_size + 1), name='scen_id')

@cash
def sex():
    return model_point()["sex"].values

@cash
def std_norm_rand():
    if hasattr(np.random, 'default_rng'):
        gen = np.random.default_rng(1234)
        rnd = gen.standard_normal((scen_size, 242))
    else:
        np.random.seed(1234)
        rnd = np.random.standard_normal(size=(scen_size, 242))
    return rnd

@cash
def sum_assured():
    return model_point()['sum_assured'].values

@cash
def surr_charge(t):
    return surr_charge_rate(t) * av_pp_at(t, "MID_MTH") * pols_lapse(t)

@cash
def surr_charge_id():
    return model_point()['surr_charge_id'].values.astype(str)

@cash
def surr_charge_max_idx():
    return max(surr_charge_table.index)

@cash
def surr_charge_rate(t):
    ind_row = np.minimum(duration(t), surr_charge_max_idx())
    return surr_charge_table.values.flat[surr_charge_table_column() + ind_row * len(surr_charge_table.columns)]

@cash
def surr_charge_table_column():
    return surr_charge_table.columns.searchsorted(surr_charge_id(), side='right') - 1

@cash
def surr_charge_table_stacked():
    return surr_charge_table.stack().reorder_levels([1, 0]).sort_index()

@cash
def point_size():
    return len(model_point_table_ext)

def savings_me_recursive_numpy():
    cash.reset() # Ensure the cache is clear before running calculations
    return float(np.sum(pv_net_cf()))

if __name__ == "__main__":
    print(savings_me_recursive_numpy())