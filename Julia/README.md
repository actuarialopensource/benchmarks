# Julia benchmarks

Benchmark code for Julia replicates [lifelib](https://lifelib.io/)'s [basiclife](https://lifelib.io/libraries/basiclife/index.html) and [savings](https://lifelib.io/libraries/savings/index.html) libraries. The former models a term life insurance, while the latter models a universal life insurance. The code for the term life model is contained within `src/mortality.jl` and `src/basic_term.jl` using a very similar architecture as the original implementation, while the rest of the package reimplements a simulator in a more Julia-idiomatic way for the universal life model.
