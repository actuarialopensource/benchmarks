import jax.numpy as jnp
import numpy as np
import pandas as pd
import equinox as eqx

# declaring what the axes are is nice
from jaxtyping import Float as F, Array as loat

# parameters
max_proj_len = 12 * 20 + 1
mp = pd.read_csv("data/model_point_table.csv")
disc_rate: F[loat, "untruncated_timesteps"] = jnp.array(
    pd.read_csv("data/disc_rate_ann.csv")["zero_spot"]
)
sum_assured: F[loat, "pols"] = jnp.array(mp["sum_assured"])
policy_term: F[loat, "pols"] = jnp.array(mp["policy_term"])
age_at_entry: F[loat, "pols"] = jnp.array(mp["age_at_entry"])
mort_jnp: F[loat, "attained_age duration"] = jnp.array(
    pd.read_csv("data/mort_table.csv").drop(columns=["Age"]).to_numpy()
)
loading_prem: F[loat, ""] = jnp.array(0.5)
expense_acq: F[loat, ""] = jnp.array(300.0)
expense_maint: F[loat, ""] = jnp.array(60.0)
inflation_rate: F[loat, ""] = jnp.array(0.01)


def run(
    disc_rate: F[loat, "untruncated_timesteps"],
    sum_assured: F[loat, "pols"],
    policy_term: F[loat, "pols"],
    age_at_entry: F[loat, "pols"],
    mort_jnp: F[loat, "attained_age duration"],
    loading_prem: F[loat, ""],
    expense_acq: F[loat, ""],
    expense_maint: F[loat, ""],
    inflation_rate: F[loat, ""],
):
    time_axis: F[loat, "timesteps"] = jnp.arange(max_proj_len)[:, None]
    duration: F[loat, "timesteps"] = time_axis // 12
    discount_factors: F[loat, "timesteps"] = (1 + disc_rate[duration]) ** (-time_axis / 12)
    inflation_factor: F[loat, "timesteps"] = (1 + inflation_rate) ** (time_axis / 12)
    lapse_rate: F[loat, "timesteps"] = jnp.maximum(0.1 - 0.02 * duration, 0.02)
    lapse_rate_monthly: F[loat, "timesteps"] = 1 - (1 - lapse_rate) ** (1 / 12)
    # is_inforce: F[loat, "timesteps pols"] = jnp.less(duration, policy_term)
    attained_age: F[loat, "timesteps pols"] = age_at_entry + duration
    annual_mortality: F[loat, "timesteps pols"] = np.array(
        mort_jnp[attained_age - 18, duration]
    )
    monthly_mortality: F[loat, "timesteps pols"] = 1 - (1 - annual_mortality) ** (1 / 12)
    pre_pols_if: F[loat, "timesteps pols"] = jnp.concatenate(
        [
            jnp.ones((1, monthly_mortality.shape[1])),
            jnp.cumprod((1 - lapse_rate_monthly) * (1 - monthly_mortality), axis=0)[:-1],
        ]
    )
    pols_if: F[loat, "timesteps pols"] = (time_axis < (policy_term * 12)) * pre_pols_if
    # pols_maturity: F[loat, "timesteps pols"] = (
    #     time_axis == (policy_term * 12)
    # ) * pre_pols_if
    pols_death: F[loat, "timesteps pols"] = pols_if * monthly_mortality
    # pols_lapse: F[loat, "timesteps pols"] = (pols_if - pols_death) * lapse_rate_monthly
    claims: F[loat, "timesteps pols"] = sum_assured * pols_death
    pv_claims: F[loat, "pols"] = jnp.sum(claims * discount_factors, axis=0)
    pv_pols_if: F[loat, "pols"] = jnp.sum(pols_if * discount_factors, axis=0)
    net_premium: F[loat, "pols"] = pv_claims / pv_pols_if
    premium_pp: F[loat, "pols"] = (1 + loading_prem) * net_premium
    premiums: F[loat, "timesteps pols"] = premium_pp * pols_if
    commissions: F[loat, "timesteps pols"] = (duration == 0) * premiums
    expenses: F[loat, "timesteps pols"] = (
        time_axis == 0
    ) * expense_acq * pols_if + pols_if * expense_maint / 12 * inflation_factor
    # results
    expenses_agg: F[loat, "timesteps"] = jnp.sum(expenses, axis=1)
    premium_agg: F[loat, "timesteps"] = jnp.sum(premiums, axis=1)
    commissions_agg: F[loat, "timesteps"] = jnp.sum(commissions, axis=1)
    claims_agg: F[loat, "timesteps"] = jnp.sum(claims, axis=1)
    net_cf_agg = premium_agg - claims_agg - expenses_agg - commissions_agg
    return {
        "commissions_agg": commissions_agg,
        "expenses_agg": expenses_agg,
        "premium_agg": premium_agg,
        "claims_agg": claims_agg,
        "net_cf_agg": net_cf_agg
    }
        

results = run(
    disc_rate=disc_rate,
    sum_assured=sum_assured,
    policy_term=policy_term,
    age_at_entry=age_at_entry,
    mort_jnp=mort_jnp,
    loading_prem=loading_prem,
    expense_acq=expense_acq,
    expense_maint=expense_maint,
    inflation_rate=inflation_rate,
)


# e2e test
assert results["net_cf_agg"][100].item() == 97661.8046875
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
