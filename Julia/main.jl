# we need the codes from mortality.jl
include("mortality.jl")
include("exposures.jl")
include("basic_term.jl")
import YAML


function run_benchmarks()
    # (result, mean time, median time) named tuple
    return Dict(
        "Julia" => Dict(
            "mortality" => run_mortality_benchmarks(),
            "exposures" => run_exposure_benchmarks(),
            "basic_term_benchmark" => run_basic_term_benchmark(),
        ),
    )
end

YAML.write_file("benchmark_results.yaml", run_benchmarks())