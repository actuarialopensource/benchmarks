import modelx as mx
import timeit

m = mx.read_model("BasicTerm_M")

def basic_term_m_lifelib():
    m.Projection.clear_cache = 1
    return m.Projection.result_cf()

def run_basic_term_benchmarks():
    trials = 20
    b1 = timeit.timeit(stmt="basic_term_m_lifelib()", setup="from basicterm import basic_term_m_lifelib", number=trials)
    return {
        "basic_term_m_lifelib": {
            "mean": f"{(b1 / trials)*1000} milliseconds",
        }
    }

if __name__ == "__main__":
    results = run_basic_term_benchmarks()
    print(results)