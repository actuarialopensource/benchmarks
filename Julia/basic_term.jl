import CacheFlow as cf

function run_basic_term_benchmark()
    cf1_benchmark = @benchmark cf.result_cf()
    # (result, mean time, median time) named tuple
    return Dict(
        "cf1" => Dict(
            "mean" => string(mean(cf1_benchmark)),
        ),
    )
end