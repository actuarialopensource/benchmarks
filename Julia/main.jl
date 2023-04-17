include("mortality.jl")
include("exposures.jl")
include("basic_term.jl")
import YAML


function run_benchmarks()
    return Dict(
            "mortality" => run_mortality_benchmarks(),
            "exposures" => run_exposure_benchmarks(),
            "basic_term_benchmark" => run_basic_term_benchmark(),
        )
end


YAML.write_file("benchmark_results.yaml", run_benchmarks())