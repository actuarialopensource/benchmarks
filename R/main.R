library(yaml)
library(readr)
library(microbenchmark)
library(magrittr)
library(dplyr)
source("exposures.R")
# use readr to read csv from ../data/census_dat.csv

census_dat <- read_csv("../data/census_dat.csv")
exposures <- expose_py(
  census_dat,
  start_date = "2006-6-15",
  end_date = "2020-02-29",
  target_status = "Surrender"
)
results <- microbenchmark(
  expose_py(
    census_dat,
    start_date = "2006-6-15",
    end_date = "2020-02-29",
    target_status = "Surrender"
  )
)

write_yaml <- function(results){
  summarised_results <- results %>%
    group_by(expr) %>%
    summarise(avg_time_ms = mean(time)/1000000)
  write_yaml(
    list(
      R = list(
        exposures = list(
          actxps = list(
            num_rows = nrow(exposures),
            mean = paste(summarised_results$avg_time_ms, "ms")
          )
        )
      )
    ),
    "benchmark_results.yaml"
  )
}

write_yaml(results)
