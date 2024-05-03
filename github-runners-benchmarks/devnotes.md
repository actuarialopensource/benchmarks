We use the devcontainer primarily to install `nektos/act` in GitHub codespaces and debug pipelines. Which doesn't always work (once network performance very bad in codespaces) perfectly but sometimes is helpful.

act -W .github/workflows/github-runners-benchmarks.yml
