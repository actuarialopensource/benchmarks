import modelx as mx
import numpy as np
import timeit

m = mx.read_model("CashValue_ME_EX4")

def savings_me_lifelib():
    m.Projection.clear_cache = 1
    m.Projection.scen_size = 1
    return float(np.sum(m.Projection.pv_net_cf()))

def run_savings_benchmarks():
    trials = 20
    modelx_time = timeit.timeit(stmt="savings_me_lifelib()", number=trials, globals = {"savings_me_lifelib": savings_me_lifelib})
    modelx_result = savings_me_lifelib()
    return {
        "Python lifelib cashvalue_me_ex4": {
            "mean": f"{(modelx_time / trials)*1000} milliseconds",
            "result": modelx_result,
        }
    }
