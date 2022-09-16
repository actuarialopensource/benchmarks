from pymort.XML import MortXML
import numpy as np
import timeit


def runner():
    select = np.array(
        [MortXML(id).Tables[0].Values.unstack().values for id in range(3299, 3309)]
    )
    ultimate = np.array(
        [MortXML(id).Tables[1].Values.unstack().values for id in range(3299, 3309)]
    )

    mortality_table_index = np.arange(10)
    duration = np.arange(25)
    issue_age = np.arange(18, 51)
    mortality_table_index, duration, issue_age = [
        x.flatten() for x in np.meshgrid(mortality_table_index, duration, issue_age)
    ]
    time_axis = np.arange(30)[:, None]
    duration_projected = time_axis + duration

    q = np.where(
        duration_projected < select.shape[-1],
        select[
            mortality_table_index,
            issue_age - 18,
            np.minimum(duration_projected, select.shape[-1] - 1),
        ],  # np.minimum avoids some out of bounds error (which shouldn't exist in the first place? JAX works without workaround)
        ultimate[mortality_table_index, issue_age - 18 + duration_projected],
    )
    npx = np.concatenate(
        [np.ones((1, q.shape[1])), np.cumprod(1 - q, axis=0)[:-1]], axis=0
    )
    v = 1 / 1.02
    v_eoy = v ** np.arange(1, 31)[:, None]
    unit_claims_discounted = npx * q * v_eoy
    return np.sum(unit_claims_discounted)


assert runner() == 1904.4865526636793
res = timeit.timeit(stmt="runner()", setup="from __main__ import runner", number=20)
print("total time: ", res)
print("average time: ", res / 20)
