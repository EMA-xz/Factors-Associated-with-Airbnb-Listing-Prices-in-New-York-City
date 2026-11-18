# Factors Associated with Airbnb Listing Prices in New York City

STAT GU4205/GR5205, Fall 2026. Initial scope: Manhattan and Brooklyn;
Entire home/apt and Private room. The research focus is regression-based
inference about listing-price associations, not causal effects.

## Evidence rule

All numerical findings, plots, and model results must be generated from the
actual pinned source data by committed R code. No simulated replacement data,
hand-entered analytical results, or fabricated findings. Written interpretation
must refer to computed outputs. Planning documents are not empirical findings.

## Current stage

Data acquisition and initial audit are implemented and executed. Read the
[code-generated audit](reports/audit/data_audit.md) before choosing the final
sample. No exploratory figures, regression results, or submission-ready report
have been produced yet. The audit documents substantial missing-price coverage
and checks minimum-stay requirements and repeated hosts.

## Reproduce

Install R (the executed version is recorded in `reports/audit/session_info.txt`).
No additional R packages are needed for this stage. From the repository root:

```sh
Rscript --vanilla scripts/02_audit_data.R
```

This downloads the fixed snapshot if absent, verifies its MD5 fingerprint,
checks unique listing IDs and required fields, and regenerates all audit outputs.
Internet access is needed only for the initial download. A changed source file
causes an error rather than silently changing the analysis. Raw and processed
row-level data are excluded from Git; retain a local copy of the fixed raw file
in case the provider later removes it. The recorded SHA-256 additionally
identifies the file at acquisition.

## Files

- `scripts/00_config.R`: source URL, snapshot and fingerprint.
- `scripts/01_download_data.R`: download and integrity check.
- `scripts/02_audit_data.R`: all audit calculations and report generation.
- `data/raw/`: unmodified compressed source data, local only.
- `data/processed/`: reproducible scoped records and preliminary EDA sample, local only.
- `reports/audit/`: generated aggregate CSVs, audit narrative and R session details.
- `docs/requirements.md`: course deliverables and implementation checklist.
- `docs/analysis_plan.md`: proposed questions, cleaning decisions and next steps.
- `docs/data_source.md`: provenance, attribution and field interpretation.

Do not manually edit generated audit files; change the code and rerun it.

## Next milestone

Inspect missing-price selection and the composition of the four groups, settle
the EDA sample definition, then generate four labeled exploratory plots and
descriptive summaries. Only then write the initial Project Description, using
those actual outputs. Teammate names/UNIs and any additional classroom rules
remain to be supplied by the team.

## Source attribution

Inside Airbnb. New York City detailed listings, snapshot labeled 2026-09-14.
Retrieved for this project on 2026-11-18. Public download:
https://insideairbnb.com/get-the-data/ . Data are provided under CC BY 4.0;
see `docs/data_source.md`. Inside Airbnb is independent of Airbnb.
