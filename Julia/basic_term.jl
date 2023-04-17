import CacheFlow as cf

function cf1()
    empty!(cf.cache_policies_inforce)
    empty!(cf.cache_premiums_pp)
    cf.result_cf()
end

function run_basic_term_benchmark()
    cf1_benchmark = @benchmark cf1()
    # (result, mean time, median time) named tuple
    return Dict(
        "Julia CacheFlow basic_term" => Dict(
            "mean" => string(mean(cf1_benchmark)),
        ),
    )
end