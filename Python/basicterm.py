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
    modelx_time = timeit.timeit(stmt="basicterm_m_lifelib()", setup="from basicterm_m_lifelib import basicterm_m_lifelib", number=trials)
    modelx_result = basicterm_m_lifelib()
    scratch_time = timeit.timeit(stmt="basicterm_scratch()", setup="from basicterm_scratch import basicterm_scratch", number=trials)
    scratch_result = basicterm_scratch()
    jax_time = timeit.timeit(stmt="basicterm_jax()", setup="from basicterm_jax import basicterm_jax", number=trials)
    jax_result = basicterm_jax()
    return {
        "Python lifelib basic_term_m": {
            "mean": f"{(modelx_time / trials)*1000} milliseconds",
            "result": modelx_result,
        },
        "Python scratch basic_term_m": {
            "mean": f"{(scratch_time / trials)*1000} milliseconds",
            "result": scratch_result,
        },
        "Python jax basic_term_m": {
            "mean": f"{(jax_time / trials)*1000} milliseconds",
            "result": jax_result,
        },
    }

if __name__ == "__main__":
    results = run_basic_term_benchmarks()
    print(results)