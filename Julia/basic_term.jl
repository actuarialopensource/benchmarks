import Benchmarks as B

function cf1()
    empty!(B.cache_policies_inforce)
    empty!(B.cache_premiums_pp)
    empty!(B.cache_monthly_basic_mortality)
    sum(B.pv_net_cf())
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
