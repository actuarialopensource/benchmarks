import numpy as np
import modelx as mx
import timeit
from basicterm_m_lifelib import basicterm_m_lifelib
from basicterm_recursive_pytorch import basicterm_recursive_pytorch
from basicterm_recursive_numpy import basicterm_recursive_numpy
from basicterm_array_pytorch import basicterm_array_pytorch
from basicterm_array_numpy import basicterm_array_numpy
from pprint import pprint

m = mx.read_model("BasicTerm_M")

def basic_term_m_lifelib():
    m.Projection.clear_cache = 1
    return m.Projection.result_cf()

def run_basic_term_benchmarks():
    trials = 20
    modelx_time = timeit.repeat(stmt="basicterm_m_lifelib()", setup="from basicterm_m_lifelib import basicterm_m_lifelib", number=1, repeat=trials)
    modelx_result = basicterm_m_lifelib()
    recursive_pytorch_time = timeit.repeat(stmt="basicterm_recursive_pytorch()", setup="from basicterm_recursive_pytorch import basicterm_recursive_pytorch", number=1, repeat=trials)
    recursive_pytorch_result = basicterm_recursive_pytorch()
    recursive_numpy_time = timeit.repeat(stmt="basicterm_recursive_numpy()", setup="from basicterm_recursive_numpy import basicterm_recursive_numpy", number=1, repeat=trials)
    recursive_numpy_result = basicterm_recursive_numpy()
    array_pytorch_time = timeit.repeat(stmt="basicterm_array_pytorch()", setup="from basicterm_array_pytorch import basicterm_array_pytorch", number=1, repeat=trials)
    array_pytorch_result = basicterm_array_pytorch()
    array_numpy_time = timeit.repeat(stmt="basicterm_array_numpy()", setup="from basicterm_array_numpy import basicterm_array_numpy", number=1, repeat=trials)
    array_numpy_result = basicterm_array_numpy()
    return {
        "Python lifelib basic_term_m": {
            "minimum time": f"{np.min(modelx_time)*1000} milliseconds",
            "result": modelx_result,
        },
        "Python recursive pytorch basic_term_m": {
            "minimum time": f"{np.min(recursive_pytorch_time)*1000} milliseconds",
            "result": recursive_pytorch_result,
        },
        "Python recursive numpy basic_term_m": {
            "minimum time": f"{np.min(recursive_numpy_time)*1000} milliseconds",
            "result": recursive_numpy_result,
        },
        "Python array pytorch basic_term_m": {
            "minimum time": f"{np.min(array_pytorch_time)*1000} milliseconds",
            "result": array_pytorch_result,
        },
        "Python array numpy basic_term_m": {
            "minimum time": f"{np.min(array_numpy_time)*1000} milliseconds",
            "result": array_numpy_result,
        }
    }

if __name__ == "__main__":
    results = run_basic_term_benchmarks()
    pprint(results)
