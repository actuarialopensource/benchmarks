# we need the codes from mortality.jl
include("mortality.jl")
include("exposures.jl")
import YAML


function run_benchmarks()
    # (result, mean time, median time) named tuple
    return Dict(
        "Julia" => Dict(
            "mortality" => run_mortality_benchmarks(),
            "exposures" => run_exposure_benchmarks(),
        ),
    )
end

YAML.write_file("benchmark_results.yaml", run_benchmarks())