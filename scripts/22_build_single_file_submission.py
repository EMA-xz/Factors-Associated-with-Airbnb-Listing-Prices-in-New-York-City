"""Build a readable, self-contained R submission from the verified analysis.

Inline source() calls; do not change statistical code or the frozen model.
The four source files checked by the historical lock are embedded as plain
text for integrity checking, not downloaded from GitHub or used as dependencies.
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/submission/Airbnb_Project.R'
SOURCE = re.compile(r'^source\("([^"]+)"\)\s*$')
sections = []


def inline(path, stack=()):
    if path in stack:
        raise ValueError(f'Circular source dependency: {path}')
    text = (ROOT / path).read_text()
    parts = [f'\n# ===== BEGIN {path} =====\n']
    sections.append(path)
    for line in text.splitlines(keepends=True):
        match = SOURCE.fullmatch(line.strip())
        if match:
            parts.append(inline(match[1], stack + (path,)))
        else:
            parts.append(line)
    parts.append(f'\n# ===== END {path} =====\n')
    return ''.join(parts)


def raw_string(text):
    # R >= 4.0 raw strings keep the source readable and byte-for-byte intact.
    assert ')---"' not in text
    return 'r"---(' + text + ')---"'


lock = json.loads((ROOT / 'config/final_model_lock.json').read_text())
audit_paths = list(lock['selection_source_md5'])
for path in audit_paths:
    assert hashlib.md5((ROOT / path).read_bytes()).hexdigest() == lock['selection_source_md5'][path]

header = '''# NYC AIRBNB PRICE PROJECT -- SINGLE-FILE R SUBMISSION
# Submit this .R file together with the written report PDF. No ZIP, GitHub
# checkout, other script, configuration file, or precomputed results are needed.
#
# HOW TO RUN (R >= 4.0, RStudio or command line)
#   RStudio: open this file and click Source (run the entire file).
#   Terminal: Rscript --vanilla Airbnb_Project.R
# Internet is needed on first run to download the fixed real dataset and any
# missing packages. Packages are installed only in the output folder's library.
# Output: airbnb_submission_output/ under the current working directory.
# An existing pinned data file may be reused via AIRBNB_RAW_DATA; otherwise
# the script downloads it directly from Inside Airbnb and verifies its hash.
# Optional AIRBNB_OUTPUT_DIR sets a different output directory.
#
# CONTENTS
# 1. Setup and embedded historical integrity records.
# 2. Source data, audit, descriptive statistics and four exploratory figures.
# 3. Host-level split, candidate models, clustered inference and diagnostics.
# 4. Training-only refinement, CV, population sensitivity and influence checks.
# 5. Frozen-model verification and reserved-host prediction evaluation.
# 6. Report figures, computed tables, text and independent numerical checks.
# Section markers below preserve the names of the original organized modules.
# Every executable source() call has been replaced by its actual R code.
#
# All analytical numbers and plots are computed from real data. The embedded
# frozen coefficients are historical verification targets, not replacements
# for fitting. The original model was frozen on 2026-11-19 (commit 26e8ecf),
# before test scoring. This script reproduces it; it does not reopen selection.
# Both Private room and Entire home/apt are included in Brooklyn and Manhattan.
# Observational associations are not causal effects; diagnostics have remaining
# limitations discussed in the report. Earlier EDA viewed the full snapshot.
#
# This file generates numerical results, PNG figures and report text in R.
# The separately submitted PDF is already typeset; reproducing its PDF/Word
# typography is not required to run this analysis and does not require Python.
# Team names and UNIs: fill in the report before submission.

submission_previous_wd <- getwd()
submission_previous_options <- options()
submission_previous_libraries <- .libPaths()
tryCatch({
  submission_output <- Sys.getenv("AIRBNB_OUTPUT_DIR", unset="")
  if (!nzchar(submission_output)) {
    submission_output <- file.path(submission_previous_wd, "airbnb_submission_output")
  }
  dir.create(submission_output, recursive=TRUE, showWarnings=FALSE)
  submission_output <- normalizePath(submission_output, mustWork=TRUE)
  submission_cached_raw <- Sys.getenv("AIRBNB_RAW_DATA", unset="")
  if (nzchar(submission_cached_raw)) {
    submission_cached_raw <- normalizePath(submission_cached_raw, mustWork=TRUE)
  }
  setwd(submission_output)
  for (folder in c("config", "scripts", "data/raw", ".r-library")) {
    dir.create(folder, recursive=TRUE, showWarnings=FALSE)
  }
  .libPaths(c(normalizePath(".r-library"), .libPaths()))
  submission_packages <- c("ggplot2", "jsonlite", "sandwich")
  submission_missing <- submission_packages[
    !vapply(submission_packages, requireNamespace, logical(1), quietly=TRUE)]
  if (length(submission_missing)) {
    install.packages(submission_missing, lib=".r-library",
                     repos="https://cloud.r-project.org")
  }
  stopifnot(all(vapply(submission_packages, requireNamespace, logical(1), quietly=TRUE)))
  # ragg is optional; the existing plotting code also supports base PNG.
  if (nzchar(submission_cached_raw)) {
    submission_raw_target <- "data/raw/nyc_listings_2026-09-14.csv.gz"
    if (!file.exists(submission_raw_target)) {
      stopifnot(file.copy(submission_cached_raw, submission_raw_target))
    }
  }

  # HISTORICAL INTEGRITY RECORDS (plain text, not hidden/encoded code).
  # Recreate the four original source texts solely for their existing MD5
  # checks, plus the immutable model lock and the team-header configuration.
  # The actual analysis below is inlined and never sources these files.
  # Refuse to overwrite differing records in an existing output folder.
  submission_write_record <- function(path, text) {
    bytes <- charToRaw(enc2utf8(text))
    if (file.exists(path)) {
      old <- readBin(path, "raw", n=file.info(path)$size)
      if (!identical(old, bytes)) stop("Existing record differs: ", path,
        ". Use an empty output folder; do not change the frozen model.")
    } else {
      writeBin(bytes, path)
    }
  }
'''
records = []
for path in audit_paths + ['config/final_model_lock.json', 'config/team.csv']:
    records.append(f'\nsubmission_write_record("{path}", {raw_string((ROOT / path).read_text())})\n')
analysis = inline('scripts/run_final_analysis.R')
assert not any(SOURCE.fullmatch(line.strip()) for line in analysis.splitlines())
footer = '''
  cat("\\nCOMPLETE: all analysis and numerical verification finished.\\n")
  cat("Output folder:", submission_output, "\\n")
  cat("Report figures: figures/final/\\n")
  cat("Final estimates and test errors: reports/final_analysis/\\n")
  cat("Computed report text: reports/final_report/final_report.md\\n")
  cat("This .R file and the report PDF are the submission files.\\n")
}, finally={
  setwd(submission_previous_wd)
  options(submission_previous_options)
  .libPaths(submission_previous_libraries)
})
'''
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(header + ''.join(records) + '\n# ===== EXECUTABLE ANALYSIS =====\n' + analysis + footer)
print(f'Built {OUT.name}: {len(OUT.read_text().splitlines())} lines; '
      f'{len(set(sections))} source modules inlined; no external source() calls.')
