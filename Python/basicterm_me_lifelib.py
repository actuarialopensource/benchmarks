import modelx as mx
import numpy as np

m = mx.read_model("BasicTerm_ME")

def basicterm_me_lifelib():
    m.Projection.clear_cache = 1
    return float(np.sum(m.Projection.pv_net_cf()))

if __name__ == "__main__":
    print(basicterm_me_lifelib())