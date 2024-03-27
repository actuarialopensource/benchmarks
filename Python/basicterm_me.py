import numpy as np
import timeit
from basicterm_me_lifelib import basicterm_me_lifelib
from basicterm_me_recursive_numpy import basicterm_me_recursive_numpy
from pprint import pprint


def run_basic_term_me_benchmarks():
    trials = 7
    modelx_time = timeit.repeat(stmt="basicterm_me_lifelib()", setup="from basicterm_me_lifelib import basicterm_me_lifelib", number=1, repeat=trials)
    modelx_result = basicterm_me_lifelib()
    recursive_numpy_time = timeit.repeat(stmt="basicterm_me_recursive_numpy()", setup="from basicterm_me_recursive_numpy import basicterm_me_recursive_numpy", number=1, repeat=trials)
    recursive_numpy_result = basicterm_me_recursive_numpy()
    return {
        "Python lifelib basic_term_me": {
            "minimum time": f"{np.min(modelx_time)*1000} milliseconds",
            "result": modelx_result,
        },
        "Python recursive numpy basic_term_me": {
            "minimum time": f"{np.min(recursive_numpy_time)*1000} milliseconds",
            "result": recursive_numpy_result,
        }
    }

if __name__ == "__main__":
    results = run_basic_term_me_benchmarks()
    pprint(results)