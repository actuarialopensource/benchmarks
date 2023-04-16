from mortality import run_mortality_benchmarks
from basicterm import run_basic_term_benchmarks
import yaml

def get_results():
    return {
        "Python": {
            "mortality": run_mortality_benchmarks(),
            "basic_term_benchmark": run_basic_term_benchmarks()
        }
    }

if __name__ == '__main__':
    results = get_results()
    # write to benchmark_results.yaml
    with open("benchmark_results.yaml", "w") as f:
        yaml.dump(results, f)
    
