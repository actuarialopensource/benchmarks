import modelx as mx
import numpy as np
import timeit

m = mx.read_model("CashValue_ME_EX4")

def savings_se_lifelib():
    m.Projection.clear_cache = 1
    m.Projection.scen_size = 1
    return float(np.sum(m.Projection.pv_net_cf()))

def run_savings_benchmarks():
    trials = 20
    modelx_time = timeit.timeit(stmt="savings_se_lifelib()", number=trials, globals = {"savings_se_lifelib": savings_se_lifelib})
    modelx_result = savings_se_lifelib()
    return {
        "Python lifelib basic_term_m": {
            "mean": f"{(modelx_time / trials)*1000} milliseconds",
            "result": modelx_result,
        }
    }
