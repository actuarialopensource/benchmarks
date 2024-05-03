import modelx as mx
import numpy as np

m = mx.read_model("BasicTerm_M")

def basicterm_m_lifelib():
    m.Projection.clear_cache = 1
    return float(np.sum(m.Projection.pv_net_cf()))