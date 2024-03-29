import numpy as np
import timeit
from savings_me_lifelib import savings_me_lifelib
from savings_me_recursive_numpy import savings_me_recursive_numpy
from pprint import pprint

def run_savings_benchmarks():
    trials = 5
    modelx_time = timeit.repeat(stmt="savings_me_lifelib()", setup="from savings_me_lifelib import savings_me_lifelib", number=1, repeat=trials)
    modelx_result = savings_me_lifelib()
    recursive_numpy_time = timeit.repeat(stmt="savings_me_recursive_numpy()", setup="from savings_me_recursive_numpy import savings_me_recursive_numpy", number=1, repeat=trials)
    recursive_numpy_result = savings_me_recursive_numpy()
    return {
        "Python lifelib cashvalue_me_ex4": {
            "minimum time": f"{np.min(modelx_time)*1000} milliseconds",
            "result": modelx_result,
        },
        "Python recursive numpy cashvalue_me_ex4": {
            "minimum time": f"{np.min(recursive_numpy_time)*1000} milliseconds",
            "result": recursive_numpy_result,
        }
    }

if __name__ == "__main__":
    print(run_savings_benchmarks())
