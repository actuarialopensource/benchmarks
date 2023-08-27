using LifeSimulator: empty_memoization_caches!, pv_net_cf

function cf1()
    empty_memoization_caches!()
    sum(pv_net_cf())
end

function run_basic_term_benchmark()
    cf1_benchmark = @benchmark cf1()
    result = cf1()
    # (result, mean time, median time) named tuple
    return Dict(
        "Julia Benchmarks basic_term" => Dict(
            "mean" => string(mean(cf1_benchmark)),
            "result" => string(result),
        ),
    )
end
