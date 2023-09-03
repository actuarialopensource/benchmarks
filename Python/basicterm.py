import numpy as np
import modelx as mx
import timeit
from basicterm_m_lifelib import basicterm_m_lifelib
from basicterm_scratch import basicterm_scratch
from basicterm_jax import basicterm_jax

m = mx.read_model("BasicTerm_M")

def basic_term_m_lifelib():
    m.Projection.clear_cache = 1
    return m.Projection.result_cf()

def run_basic_term_benchmarks():
    trials = 20
    modelx_time = timeit.repeat(stmt="basicterm_m_lifelib()", setup="from basicterm_m_lifelib import basicterm_m_lifelib", number=1, repeat=trials)
    modelx_result = basicterm_m_lifelib()
    scratch_time = timeit.repeat(stmt="basicterm_scratch()", setup="from basicterm_scratch import basicterm_scratch", number=1, repeat=trials)
    scratch_result = basicterm_scratch()
    jax_time = timeit.repeat(stmt="basicterm_jax()", setup="from basicterm_jax import basicterm_jax", number=1, repeat=trials)
    jax_result = basicterm_jax()
    return {
        "Python lifelib basic_term_m": {
            "minimum time": f"{np.min(modelx_time)*1000} milliseconds",
            "result": modelx_result,
        },
        "Python scratch basic_term_m": {
            "minimum time": f"{np.min(scratch_time)*1000} milliseconds",
            "result": scratch_result,
        },
        "Python jax basic_term_m": {
            "minimum time": f"{np.min(jax_time)*1000} milliseconds",
            "result": jax_result,
        },
    }

if __name__ == "__main__":
    results = run_basic_term_benchmarks()
    print(results)
