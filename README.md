# Benchmarks

Reproducible benchmarks for open source actuarial applications.

Each folder contains a dockerfile, and a script for publishing/running the test on Google Cloud's Vertex AI.

## Mortality

### Calculation details

Policies consist of all combinations of the following -

- 2017 Loaded CSO Preferred Structure ANB tables (10 options)
- Initial durations in the range [1, 25] (25 options)
- Issue ages in the range [18, 50] (33 options)

This gives us `10 * 25 * 33 = 8250` policies.

We calculate the discounted (`r=.02`) expected benefits for a $1 face amount for 30 time steps for each policy, storing the cash flows in an array of size `(30, 8250)`, `(timesteps, policies)`. We then sum the cashflows to yield an answer of `1904.486552663679`, which both Python and Julia agree on.

### Results summary

| library                                                                  | run 1   | run 2   | lines of code | source code                                                                          |
| ------------------------------------------------------------------------ | ------- | ------- | ------------- | ------------------------------------------------------------------------------------ |
| [MortalityTables.jl](https://github.com/JuliaActuary/MortalityTables.jl) | 4ms     | 5ms     | 13            | [link](https://github.com/actuarialopensource/benchmarks/tree/main/mortality/julia)  |
| [pymort](https://github.com/actuarialopensource/pymort)                  | 1,889ms | 1,922ms | 30            | [link](https://github.com/actuarialopensource/benchmarks/tree/main/mortality/python) |

### Notes on differences in runtime

Two performance bottlenecks on PyMort are the following:

1. Pymort parses XML files at runtime to construct `MortXML` objects.
   - Pickling the MortXML object and loading that instead of parsing XML at runtime should speed this up.
2. `MortXML` objects store rates in Pandas dataframes, which need to be converted to NumPy arrays using `.unstack().values`.

### Notes on differences in lines of code

- Julia uses a list comprehension to get the rates into the desired array formatting. There aren't separate select and ultimate tables, there is just a rate vector for a particular issue age. This eliminates the need for logic that determines which table we belong to.
- Pymort has to work a bit harder to do certain things
  - select the correct rate according to duration and issue age (8 lines)
  - convert rate tables from Pandas to NumPy (6 lines)
  - creating all possible combinations of policies is a bit harder (3 lines)
  - create a NumPy array that represents the durations for each policy at each point in time (1 line)

The Black formatter for Python keeps lines short by breaking things up into new lines, this is good practice so we do it in the benchmark.

### A word from the authors

> The MortXML object is intended to be a Pythonic object-oriented wrapper for the standard XML mortality tables. It is apparently not optimized for this benchmark. I was surprised to see Julia's ability to create a NumPy-like array using a list comprehension. There are some good design decisions in the Julia language and in the MortalityTables.jl package. - _Author of Pymort and these benchmarks, Matthew Caseres_
