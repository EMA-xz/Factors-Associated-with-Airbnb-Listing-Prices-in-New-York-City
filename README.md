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

The initial Project Description is available as a
[PDF](reports/project_description/project_description.pdf),
[editable Word document](reports/project_description/project_description.docx),
and [Markdown source](reports/project_description/project_description.md).
All empirical values come from R outputs. Team names and UNIs have not yet been
supplied: the author line is blank, so this is not ready to submit unchanged.

Data acquisition, audit, descriptive analysis and four exploratory figures are
implemented. Detailed evidence is in the [generated EDA report](reports/eda/eda_report.md).
The [initial audit](reports/audit/data_audit.md) documents the sample accounting.
The EDA report examines price coverage, minimum-stay composition, property types
and unadjusted prices. The [model protocol](reports/model_preparation/model_protocol.md)
defines eligible samples, candidate formulas and a fixed host-level train/test
split. No regression has been fitted. All statistics and figures are generated
by the scripts.

## Reproduce

Install R (the executed version is recorded in `reports/audit/session_info.txt`).
The audit alone needs no external packages. From the repository root:

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

To reproduce the descriptive analysis, all four figures and the EDA report:

```r
install.packages(c("ggplot2", "ragg")) # one-time setup; ragg is optional
```

```sh
Rscript --vanilla scripts/04_generate_eda.R
```

This command rebuilds the audit and EDA from the raw source; it does not consume
manually edited summary files. The exact executed R/package versions are recorded
in `reports/eda/session_info.txt`. The PNG renderer uses ragg when installed, with
base R PNG as a fallback; pixel appearance may differ across systems/renderers.
The plotted jitter has a fixed seed and changes only horizontal display position.

To regenerate model eligibility and the host split without building documents:

```sh
Rscript --vanilla scripts/05_prepare_model_samples.R
```

To build the full initial report from the pinned data:

```r
install.packages(c("ggplot2", "ragg", "jsonlite")) # one-time R setup
```

```sh
python3 -m pip install -r requirements-report.txt
Rscript --vanilla scripts/06_prepare_project_description.R
python3 scripts/07_build_project_description.py
python3 scripts/08_validate_project_outputs.py
```

Run these from the repository root. R regenerates statistics, figures, model
preparation and a shared JSON/text report payload. Python lays out that payload
as DOCX and PDF; it does not calculate or invent analytical results. Add the real
3-5 team members to `config/team.csv` (columns `name,uni`) and rebuild to populate
the author line. A blank roster is allowed for drafts; a partially filled or
invalid roster stops report preparation. The standalone PDF and editable DOCX
have the same content but use separate rendering engines, so typography can vary.
The validator checks source-file integrity, host separation, sensitivity-subset
consistency, group counts, embedded figure hashes, and report text/table content.
It records whether team metadata are complete; a successful integrity check does
not mean an unsigned report is ready for submission or that a model is valid.

## Files

- `scripts/00_config.R`: source URL, snapshot and fingerprint.
- `scripts/01_download_data.R`: download and integrity check.
- `scripts/02_audit_data.R`: all audit calculations and report generation.
- `scripts/03_descriptive_analysis.R`: coverage, stay composition, property labels and descriptive statistics.
- `scripts/04_generate_eda.R`: four PNG figures and the EDA report; complete entry point.
- `scripts/05_prepare_model_samples.R`: sample eligibility and saved host split, without model fitting.
- `config/model_spec.R`: pre-fit inclusion/split settings, reference levels and candidate formulas.
- `scripts/06_prepare_project_description.R`: regenerate all report content from R outputs.
- `scripts/07_build_project_description.py`: render the shared report payload as DOCX/PDF.
- `scripts/08_validate_project_outputs.py`: check data/report integrity and record roster completeness.
- `config/team.csv`: team names/UNIs, currently a blank header awaiting real information.
- `data/raw/`: unmodified compressed source data, local only.
- `data/processed/`: reproducible scoped records and preliminary EDA sample, local only.
- `reports/audit/`: generated aggregate CSVs, audit narrative and R session details.
- `reports/eda/`: generated descriptive statistics, coverage checks, figure inputs and EDA narrative.
- `reports/model_preparation/`: generated sample-flow, split-count and modeling-protocol files.
- `reports/project_description/`: generated five-page initial report and its text/data payload.
- `figures/`: four code-generated PNG plots, with labels, sample information and sources.
- `docs/requirements.md`: course deliverables and implementation checklist.
- `docs/analysis_plan.md`: proposed questions, cleaning decisions and next steps.
- `docs/data_source.md`: provenance, attribution and field interpretation.

Do not manually edit generated reports, statistics or figures; change the code and rerun it.

## Next milestone

Add team names/UNIs, review the initial Project Description, and reconcile any
additional classroom instructions. Then fit the predeclared candidate models on
the saved training partition, run diagnostics, and perform one property-label
sensitivity analysis using the same model form and inherited split. Earlier EDA
viewed the full snapshot; this is a prospective holdout for later model decisions,
not a never-viewed external test sample. Price missingness remains a limitation.

## Source attribution

Inside Airbnb. New York City detailed listings, snapshot labeled 2026-09-14.
Retrieved for this project on 2026-11-18. Public download:
https://insideairbnb.com/get-the-data/ . Data are provided under CC BY 4.0;
see `docs/data_source.md`. Inside Airbnb is independent of Airbnb.
