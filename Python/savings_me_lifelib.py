import modelx as mx
import numpy as np
import timeit
import pandas as pd
from os.path import dirname, join

m = mx.read_model("CashValue_ME_EX4")

def savings_me_lifelib():
    m.Projection.clear_cache = 1
    m.Projection.scen_size = 1
    model_file = join(dirname(dirname(__file__)), "Julia", "src", "data", "savings", "model_point_table_10K.csv")
    m.Projection.model_point_table = pd.read_csv(model_file)
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
