import modelx as mx
import numpy as np
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
