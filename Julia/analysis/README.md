# Analysis

To reproduce the images found under `./images` (currently shown in the README), simply run

```bash
/path/to/benchmarks/Julia/analysis$ julia --color=yes --project analysis.jl
```

Running the various benchmarks and timings will take at least a few minutes.

You will likely a machine with at least 16 GB of RAM. 32 GB of RAM is recommended for running the model with 10,000,000 points (last stage of the analysis to stress-test and evaluate the performance at large scale).
