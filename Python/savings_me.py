import timeit
from savings_me_lifelib import savings_me_lifelib
from savings_me_recursive_numpy import savings_me_recursive_numpy
import numpy as np

def run_savings_benchmarks():
    trials = 10
    modelx_time = timeit.repeat(stmt="savings_me_lifelib()", number=1, repeat=trials, globals = {"savings_me_lifelib": savings_me_lifelib})
    modelx_result = savings_me_lifelib()
    numpy_recursive_time = timeit.repeat(stmt="savings_me_recursive_numpy()", number=1, repeat=trials, globals = {"savings_me_recursive_numpy": savings_me_recursive_numpy})
    numpy_recursive_result = savings_me_recursive_numpy()
    return {
        "Python lifelib cashvalue_me_ex4": {
            "minimum time": f"{np.min(modelx_time)*1000} milliseconds",
            "result": modelx_result,
        },
        "Python recursive numpy cashvalue_me_ex4": {
            "minimum time": f"{np.min(numpy_recursive_time)*1000} milliseconds",
            "result": numpy_recursive_result,
        }
    }

if __name__ == "__main__":
    results = run_savings_benchmarks()
    print(results)