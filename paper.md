---
title: 'Actuarial Open Source Benchmarks: Testing actuarial models on CPU and GPU'
tags:
  - Python
  - Julia
  - actuarial science
  - GPU
  - performance testing
authors:
  - name: Matthew Caseres
    orcid: 0000-0001-5819-001X
    equal-contrib: true
    affiliation: "1, 2" # (Multiple affiliations must be quoted)
  - name: Author Without ORCID
    equal-contrib: true # (This is how you can denote equal contributions between multiple authors)
    affiliation: 2
affiliations:
 - name: Georgia Institute of Technology, USA
   index: 1
 - name: Intrepid Direct Insurance, USA
   index: 2
date: 27 May 2024
bibliography: paper.bib
---

* market share of actuarial modeling systems.
    * https://www.seactuary.com/files/meetings/2021Fall/2021SEACAnnualHalloran(AM).pdf
* AI and modeling "While we do not provide the code to produce the data generation since we used a vendor software,"
    * https://www.soa.org/resources/research-reports/2023/predictive-analytics-and-machine-learning/
* https://lifelib.io/
  * https://modelx.io/blog/2022/02/20/testing-gpu-model-on-cloud/
  * https://modelx.io/blog/2022/03/26/running-model-while-saving-memory/
* mortality tables
  * https://github.com/actuarialopensource/pymort
  * https://juliaactuary.org/packages/
* experience analysis
  * https://mattheaphy.github.io/actxps/authors.html#citation
  * https://juliaactuary.org/packages/
* model validation - https://www.soa.org/4934a6/globalassets/assets/library/newsletters/the-modeling-platform/2017/november/mp-2017-iss6-hall-minnes-natchev.pdf
* data clustering applications
  * https://www.tandfonline.com/doi/abs/10.1080/10920277.2019.1575242
https://www.pwc.com/us/en/industries/financial-services/library/future-of-actuarial-modeling.html

# Summary

Actuaries are employed by insurance companies to manage risk related to uncertain future cashflows and play a large role in regulatory compliance for insurance companies.
Financial and statistical models are used to forecast future economic scenarios and cash flows related to insurance contracts.
The benchmarks provided in the Actuarial Open Source GitHub organization test the consistency and performance of existing open source actuarial models and provides novel approaches to achieve greater performance and scale on certain tasks.


# Statement of need

Regulators, auditors, and insurance companies validate the correctness of actuarial models to ensure correctness when reporting financial results [CITE MODEL VALIDATION]. When two actuaries implement the same thing, we can compare them. This technique has been used by the actuarial package chainladder-python with tests that compare results to similar software in R.

There is significant interest in running models on the GPU. `@Kinrade:2024`.



The benchmarks repository for the Actuarial Open Source GitHub organization tests the correctness and performance of various open source actuarial packages. 
* Actuaries 

* Performance of actuarial models is an open research area.
* Proprietary actuarial modeling platforms dominate the space for cash flow modeling.
* The usage of proprietary actuarial models has been cited as a reason that work cannot be shared.

# Benchmarking infrastructure

Calculations performed on CPU are run with GitHub actions on GitHub hosted runners. We found that the runtimes reported from Github hosted runners are generally consistent between runs and this has been independently verified by Milliman `@Milliman:2024`. 

Calculations performed on GPU are published to DockerHub using GitHub actions and tested on GPUs in the cloud.

# Benchmark categories

## LifeLib life insurance cash flow models

Reducing computational requirements for life insurance cash flow models is an active research area, but we are unaware of any standardized benchmarks where people compete to achieve the state-of-the-art as there is in deep learning.

LifeLib is an open source library that contains reference implementations for various life insurance product cash flow models. We provide implementations in Python and Julia to assess the performance and readability of the following strategies:

* Recursion with memoization
* Recursion with memoization and cache eviction to reduce memory consumption
* Array based models using broadcasting and avoiding iteration
* Array based models using iteration that are optimized to reduce memory consumption


## Experience studies

Some actuarial techniques for calculating mortality rates involve partitioning date ranges`Atkinson:2016`. These date partitioning algorithms are implemented by the actxps R package[CITE] and the ExperienceAnalysis.jl [CITE IT] Julia package . The benchmarking process identified a number of inconsistencies which were raised as issues on GitHub and quickly resolved by the maintainers of the packages.

## Mortality tables software

The Society of Actuaries provides a number of mortality tables in an XML format `Strommen:2013`. These tables have been wrapped into packages for convenient access with the pymort[CITE PYMORT] Python package and the MortalityTables.jl[CITE IT] Julia package. There are many XML files and each XML file contains many numbers. It is not practical to verify that each package correctly parses every value from every XML file. A hash was computed using each value from 10 files. Upon finding that both packages computed the same hash, confidence in the correctness of the software is higher.

# Conclusion

The benchmarks provided by the Actuarial Open Source organization on GitHub intend to assist in testing the accuracy and performance of open source actuarial software. This is accomplished by selecting a specific actuarial calculation and comparing the results and runtimes of various approaches. 

Our current benchmarks are chosen for simplicity so that the barrier to entry remains low. We have not implemented complex calculations like nested stochastic variable annuity models which may benefit from the creation of concrete benchmarks to facilitate the establishment of a state-of-the-art. The creation of more complex benchmarks that are representative of the computational challenges facing the industry will require broader community and institutional engagement.

# Acknowledgements

I thank Alec Loudenback for submitting benchmarks, providing feedback through GitHub issues, and creating many Julia packages through the JuliaActuary GitHub organization. I thank Fumito Hamamura for creating LifeLib, the Actuarial Open Source LinkedIn community page, modelx, and the incredible insights found on the modelx blog. Without them, I would never have started any of this work. Many thanks Cédric Belmant for providing a Julia implementation to the universal life benchmark which is incredibly hard to beat and to Matt Heaphy for his implementations of experience studies software in R and Python.

# Citations

Citations to entries in paper.bib should be in
[rMarkdown](http://rmarkdown.rstudio.com/authoring_bibliographies_and_citations.html)
format.

If you want to cite a software repository URL (e.g. something on GitHub without a preferred
citation) then you can do it with the example BibTeX entry below for @fidgit.

For a quick reference, the following citation commands can be used:
- `@author:2001`  ->  "Author et al. (2001)"
- `[@author:2001]` -> "(Author et al., 2001)"
- `[@author1:2001; @author2:2001]` -> "(Author1 et al., 2001; Author2 et al., 2002)"

# Figures

Figures can be included like this:
![Caption for example figure.\label{fig:example}](figure.png)
and referenced from text using \autoref{fig:example}.

Figure sizes can be customized by adding an optional second parameter:
![Caption for example figure.](figure.png){ width=20% }


# References