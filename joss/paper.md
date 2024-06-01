---
title: 'Actuarial Open Source Benchmarks: Performance testing actuarial models on CPU and GPU'
tags:
  - Python
  - Julia
  - actuarial science
  - GPU
  - performance testing
authors:
  - name: Matthew Caseres
    orcid: 0000-0001-5819-001X
    affiliation: 1
affiliations:
 - name: Georgia Institute of Technology, USA
   index: 1
date: 27 May 2024
bibliography: paper.bib
---

# Summary

Actuaries are employed by insurance companies to manage risk related to uncertain future cashflows and play a large role in regulatory compliance for insurance companies.
Actuarial models are used to forecast future economic scenarios and cash flows related to insurance contracts. The benchmarks provided in the Actuarial Open Source GitHub organization test the consistency and performance of existing open source actuarial models and provides novel approaches to achieve greater performance and scale on certain tasks.

# Statement of need

The actuarial modeling software market is dominated by large vendors [@Halloran:2021; @Kinrade:2024]. Vendor software can restrict the sharing of actuarial software [@Larochelle:2023], demonstrating the value of open source solutions in enabling reproducible research.

A 2024 PwC publication [@Kinrade:2024] speculates that graphics processing units (GPUs) may become the norm for actuarial calculation engines. Despite discussion of actuarial models running on GPUs in several publications [@Kim:2018; @Hamamura:2022a; @Robidoux:2016], there are no reproducible benchmarks for GPU-based actuarial applications.

On the CPU, the ecosystem is more mature and multiple open source packages might implement a particular calculation. In this case we can compare the execution time of the packages on a specific task and validate that the packages can produce the same results.

# Benchmarking infrastructure

Calculations performed on CPU are run with GitHub actions on GitHub-hosted runners. We found that the execution times reported from GitHub hosted runners are generally consistent between runs and this has been independently verified by Milliman [@Milliman:2024]. 

Calculations performed on GPU are published to DockerHub using GitHub actions and tested on GPUs in the cloud.

# Benchmark categories

## LifeLib life insurance cash flow models

LifeLib [@Hamamura:2018] is an open source library that contains reference implementations for various life insurance product cash flow models. We provide implementations in Python and Julia to assess the performance and coding style of the following strategies:

* Recursion with memoization
* Recursion with memoization and cache eviction to reduce memory consumption [@Hamamura:2022b]
* Array based models using broadcasting and avoiding iteration
* Array based models using iteration that are optimized to reduce memory consumption [@Belmant:2022]

## Experience studies

Some actuarial techniques for calculating mortality rates involve partitioning date ranges [@Atkinson:2016]. These date partitioning algorithms are implemented by the actxps R package [@Heaphy:2024] and the ExperienceAnalysis.jl [@Loudenback:2020] Julia package. The benchmarking process identified a number of inconsistencies which were raised as issues on GitHub and quickly resolved by the maintainers of the packages.

## Mortality tables software

The Society of Actuaries provides a number of mortality tables in an XML format [@Strommen:2013]. These tables have been wrapped into packages for convenient access with the pymort [@Caseres:2021] Python package and the MortalityTables.jl [@Loudenback:2018] Julia package. A hash was computed using each value from 10 files verifying that the values are consistent between the two packages for these files. The Julia implementation was significantly faster.

# Conclusion

The benchmarks provided by the Actuarial Open Source organization on GitHub intend to assist in testing the performance and accuracy of open source actuarial software. This is accomplished by selecting a specific actuarial calculation and comparing the results and execution times of various approaches. 

Our current benchmarks are chosen for simplicity so that the barrier to entry remains low. We have not implemented complex calculations like nested stochastic variable annuity models which could benefit from concrete benchmarks. More complex benchmarks that represent the computational challenges facing the insurance industry will require broader community engagement.

# Acknowledgements

I thank Alec Loudenback for contributing Julia benchmarks, providing feedback through GitHub issues, and creating many Julia packages through the JuliaActuary GitHub organization. I thank Fumito Hamamura for creating LifeLib, the Actuarial Open Source LinkedIn community page, modelx, and the  insights found on the modelx blog. Many thanks Cédric Belmant for providing a Julia implementation to the universal life benchmark which is incredibly hard to beat and to Matt Heaphy for his implementations of experience studies software in R and Python.

# References