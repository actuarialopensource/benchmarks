import modelx as mx
import timeit

m = mx.read_model("BasicTerm_M")

def basic_term_m_lifelib():
    m.Projection.clear_cache = 1
    return m.Projection.result_cf()

def run_basic_term_benchmarks():
    trials = 20
    modelx_time = timeit.timeit(stmt="basic_term_m_lifelib()", setup="from basicterm import basic_term_m_lifelib", number=trials)
    scratch_time = timeit.timeit(stmt="basic_term_m_scratch()", setup="from basicterm_scratch import basic_term_m_scratch", number=trials)
    return {
        "Python lifelib basic_term_m": {
            "mean": f"{(modelx_time / trials)*1000} milliseconds",
        },
        "Python scratch basic_term_m": {
            "mean": f"{(scratch_time / trials)*1000} milliseconds",
        }
    }

if __name__ == "__main__":
    results = run_basic_term_benchmarks()
    print(results)