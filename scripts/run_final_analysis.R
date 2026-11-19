# Run from the repository root after installing the documented dependencies.
# This regenerates analyses and verifies the fixed model; it never retunes to test errors.
options(warn=2)
source("scripts/17_prepare_final_report.R")
source("scripts/13_verify_training.R")
source("scripts/19_verify_final_analysis.R")
