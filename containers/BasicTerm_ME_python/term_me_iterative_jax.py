import jax
import pandas as pd
import numpy as np
import timeit
import jax.numpy as jnp
import equinox as eqx
jax.config.update("jax_enable_x64", True)

disc_rate_ann = pd.read_excel("BasicTerm_ME/disc_rate_ann.xlsx", index_col=0)
mort_table = pd.read_excel("BasicTerm_ME/mort_table.xlsx", index_col=0)
model_point_table = pd.read_excel("BasicTerm_ME/model_point_table.xlsx", index_col=0)
# model_point_table =  model_point_table = model_point_table.iloc[[0]]
premium_table = pd.read_excel("BasicTerm_ME/premium_table.xlsx", index_col=[0,1])

class ModelPointsEqx(eqx.Module):
    premium_pp: jnp.ndarray
    duration_mth: jnp.ndarray
    age_at_entry: jnp.ndarray
    sum_assured: jnp.ndarray
    policy_count: jnp.ndarray
    policy_term: jnp.ndarray
    max_proj_len: jnp.ndarray

    def __init__(self, model_point_table: pd.DataFrame, premium_table: pd.DataFrame, size_multiplier: int = 1):
        table = model_point_table.merge(premium_table, left_on=["age_at_entry", "policy_term"], right_index=True)
        table.sort_values(by="policy_id", inplace=True)
        print(table)
        self.premium_pp = jnp.round(jnp.array(np.tile(table["sum_assured"].to_numpy() * table["premium_rate"].to_numpy(), size_multiplier)),decimals=2)
        self.duration_mth = jnp.array(jnp.tile(table["duration_mth"].to_numpy(), size_multiplier))
        self.age_at_entry = jnp.array(jnp.tile(table["age_at_entry"].to_numpy(), size_multiplier))
        self.sum_assured = jnp.array(jnp.tile(table["sum_assured"].to_numpy(), size_multiplier))
        self.policy_count = jnp.array(jnp.tile(table["policy_count"].to_numpy(), size_multiplier))
        self.policy_term = jnp.array(jnp.tile(table["policy_term"].to_numpy(), size_multiplier))
        self.max_proj_len = jnp.max(12 * self.policy_term - self.duration_mth) + 1

class AssumptionsEqx(eqx.Module):
    disc_rate_ann: jnp.ndarray
    mort_table: jnp.ndarray
    expense_acq: jnp.ndarray
    expense_maint: jnp.ndarray

    def __init__(self, disc_rate_ann: pd.DataFrame, mort_table: pd.DataFrame):
        self.disc_rate_ann = jnp.array(disc_rate_ann["zero_spot"].to_numpy())
        # Get the shape of the original data from the "zero_spot" column.
        zero_spot_shape = disc_rate_ann["zero_spot"].to_numpy().shape

        # Create a JAX array of zeros with the same shape.
        # self.disc_rate_ann = jnp.zeros(zero_spot_shape, dtype=jnp.float64)
        self.mort_table = jnp.array(mort_table.to_numpy())
        self.expense_acq = jnp.array(300)
        self.expense_maint = jnp.array(60)

class LoopState(eqx.Module):
    t: jnp.ndarray
    tot: jnp.ndarray
    pols_lapse_prev: jnp.ndarray
    pols_death_prev: jnp.ndarray
    pols_if_at_BEF_DECR_prev: jnp.ndarray

class TermME(eqx.Module):
    mp: ModelPointsEqx
    assume: AssumptionsEqx
    init_ls: LoopState

    def __init__(self, mp: ModelPointsEqx, assume: AssumptionsEqx):
        self.mp = mp
        self.assume = assume
        self.init_ls = LoopState(
            t=jnp.array(0),
            tot = jnp.array(0),
            pols_lapse_prev=jnp.zeros_like(self.mp.duration_mth, dtype=jnp.float64),
            pols_death_prev=jnp.zeros_like(self.mp.duration_mth, dtype=jnp.float64),
            pols_if_at_BEF_DECR_prev=jnp.where(self.mp.duration_mth > 0, self.mp.policy_count, 0.)
        )

    def __call__(self):
        def iterative_core(ls: LoopState, _):
            duration_month_t = self.mp.duration_mth + ls.t
            duration_t = duration_month_t // 12
            age_t = self.mp.age_at_entry + duration_t
            pols_if_init = ls.pols_if_at_BEF_DECR_prev - ls.pols_lapse_prev - ls.pols_death_prev
            pols_if_at_BEF_MAT = pols_if_init
            pols_maturity = (duration_month_t == self.mp.policy_term * 12) * pols_if_at_BEF_MAT
            pols_if_at_BEF_NB = pols_if_at_BEF_MAT - pols_maturity
            pols_new_biz = jnp.where(duration_month_t == 0, self.mp.policy_count, 0)
            pols_if_at_BEF_DECR = pols_if_at_BEF_NB + pols_new_biz
            mort_rate = self.assume.mort_table[age_t-18 - jnp.clip(duration_t, a_max=5), jnp.clip(duration_t, a_max=5)]
            mort_rate_mth = 1 - (1 - mort_rate) ** (1/12)
            pols_death = pols_if_at_BEF_DECR * mort_rate_mth
            claims = self.mp.sum_assured * pols_death
            premiums = self.mp.premium_pp * pols_if_at_BEF_DECR
            commissions = (duration_month_t == 0) * premiums
            discount = (1 + self.assume.disc_rate_ann[ls.t//12+1]) ** (-ls.t/12)
            inflation_factor = (1 + 0.01) ** (ls.t/12)
            expenses = self.assume.expense_acq * pols_new_biz + pols_if_at_BEF_DECR * self.assume.expense_maint/12 * inflation_factor
            lapse_rate = jnp.clip(0.1 - 0.02 * duration_t, a_min=0.02)
            net_cf = premiums - claims - expenses - commissions
            undiscounted_net_cf = jnp.sum(net_cf)
                    
            # # Debug printing each variable
            # jax.debug.print("duration_month_t = {}", duration_month_t)
            # jax.debug.print("duration_t = {}", duration_t)
            # jax.debug.print("age_t = {}", age_t)
            # jax.debug.print("pols_if_init = {}", pols_if_init)
            # jax.debug.print("pols_if_at_BEF_MAT = {}", pols_if_at_BEF_MAT)
            # jax.debug.print("pols_maturity = {}", pols_maturity)
            # jax.debug.print("pols_if_at_BEF_NB = {}", pols_if_at_BEF_NB)
            # jax.debug.print("pols_new_biz = {}", pols_new_biz)
            # jax.debug.print("pols_if_at_BEF_DECR = {}", pols_if_at_BEF_DECR)
            # jax.debug.print("mort_rate = {}", mort_rate)
            # jax.debug.print("mort_rate_mth = {}", mort_rate_mth)
            # jax.debug.print("pols_death = {}", pols_death)
            # jax.debug.print("claims = {}", claims)
            # jax.debug.print("premiums = {}", premiums)
            # jax.debug.print("commissions = {}", commissions)
            # jax.debug.print("discount = {}", discount)
            # jax.debug.print("inflation_factor = {}", inflation_factor)
            # jax.debug.print("expenses = {}", expenses)
            # jax.debug.print("lapse_rate = {}", lapse_rate)
            # jax.debug.print("lapses = {}", (pols_if_at_BEF_DECR - pols_death) * (1 - (1 - lapse_rate) ** (1/12)))
            # jax.debug.print("net_cf = {}", net_cf)
            # jax.debug.print("undiscounted_net_cf = {}", undiscounted_net_cf)
            # jax.debug.print("---")

            discounted_net_cf = undiscounted_net_cf * discount
            nxt_ls = LoopState(
                t=ls.t+1,
                tot = ls.tot + discounted_net_cf,
                pols_lapse_prev=(pols_if_at_BEF_DECR - pols_death) * (1 - (1 - lapse_rate) ** (1/12)),
                pols_death_prev=pols_death,
                pols_if_at_BEF_DECR_prev=pols_if_at_BEF_DECR
            )
            return nxt_ls, None
            
        return jax.lax.scan(iterative_core, self.init_ls, xs=None, length=277)[0].tot


def run_jax_term_ME(term_me: TermME):
    return term_me()

run_jax_term_ME_opt = jax.jit(run_jax_term_ME)

def time_jax_func(mp, assume, func):
    term_me = TermME(mp, assume)
    result = func(term_me).block_until_ready()
    start = timeit.default_timer()
    result = func(term_me).block_until_ready()
    end = timeit.default_timer()
    elapsed_time = end - start  # Time in seconds
    print(result)
    return float(result), elapsed_time

def time_iterative_jax(multiplier: int):
    mp = ModelPointsEqx(model_point_table, premium_table, size_multiplier=multiplier)
    assume = AssumptionsEqx(disc_rate_ann, mort_table)
    result, time_in_seconds = time_jax_func(mp, assume, run_jax_term_ME_opt)
    print("JAX iterative model")
    print(f"number modelpoints={len(mp.duration_mth):,}")
    print(f"{result=:,}")
    print(f"{time_in_seconds=}")

if __name__ == "__main__":
    time_iterative_jax(1)