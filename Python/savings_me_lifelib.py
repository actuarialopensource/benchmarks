import modelx as mx
import numpy as np
import timeit
import pandas as pd
from os.path import dirname, join

m = mx.read_model("CashValue_ME_EX4")
model_file = join(dirname(__file__), "CashValue_ME_EX4", "model_point_table_10K.csv")
m.Projection.model_point_table = pd.read_csv(model_file)
m.Projection.scen_size = 1
print(m.Projection.max_proj_len())

def savings_me_lifelib():
    m.Projection.clear_cache = 1
    return float(np.sum(m.Projection.pv_net_cf()))

def run_savings_benchmarks():
    trials = 20
    modelx_time = timeit.repeat(stmt="savings_me_lifelib()", number=1, repeat=trials, globals = {"savings_me_lifelib": savings_me_lifelib})
    modelx_result = savings_me_lifelib()
    return {
        "Python lifelib cashvalue_me_ex4": {
            "minimum time": f"{np.min(modelx_time)*1000} milliseconds",
            "result": modelx_result,
        }
    }
