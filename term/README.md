# Term Life Benchmark (Beta)

We are still working out some specifics of what this benchmark should be. See open issues on GitHub.

## Modelpoints

We create a modelpoint file consisting of all possible `98,400` possible combinations of the following.

```jl
issue_age = 20:60
mortality_tables = 3299:3308
face_amounts = [25000.0, 50000.0, 100_000.0, 250_000.0, 1_000_000.0]
premium_modes = ["Annual", "Semiannual", "Quarterly", "Monthly"]
premium_jumps = [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0, 12.0, 16.0, 20.0, 22.0]
```

This is generated in `./julia/modelpoint_gen.jl` and saved as `./julia/modelpoints.csv`.

## GLM Lookup

The modelpoints include encodings to simplify looking up the appropriate lapse rate from a generalized linear model (GLM). Predictions for the GLM are done in `predict.jl`.

The GLM model is based on the GLM for duration 10 lapses from [this report](https://www.soa.org/493807/globalassets/assets/files/research/exp-study/research-2014-post-level-shock-report.pdf) (see page 113 for example calculation).

## Results

| language | mean time  |
| -------- | ---------- |
| Julia    | 457.765 ms |
