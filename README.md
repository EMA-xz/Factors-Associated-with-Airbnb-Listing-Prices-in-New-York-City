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

The final regression analysis is complete. The ten-page report is available as
[PDF](reports/final_report/final_report.pdf), [editable Word](reports/final_report/final_report.docx)
and [Markdown](reports/final_report/final_report.md). All report numbers come
from R. Team names and UNIs remain blank, so the report still needs the real
roster and team review before submission.

M3 was frozen in commit `26e8ecf` before the first reserved-host evaluation.
The final specification, coefficients, preprocessing and source fingerprints are
in [the model lock](config/final_model_lock.json). A single additional training
candidate allowing room-specific capacity slopes did not meet the pre-recorded
adoption threshold. The [decision record](reports/final_analysis/specification_decision.md)
explains parsimony, common support and remaining limitations. Test scores are in
[test_metrics.csv](reports/final_analysis/test_metrics.csv); the model was not
retuned after inspecting them. Private room remains included.

The revised report clarifies the observed nightly quote, collects model-variable
definitions on page 4 and explains the M0-M4 selection steps on page 7. The
[quote measurement audit](reports/audit/price_quote_measurement.csv) is computed
from the original fields, distinguishing quoted stay length from a listing's
minimum-stay requirement. This clarification does not change the sample or model.

### Earlier stage artifacts

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
split. Training-only regression, host-cluster inference, diagnostic plots,
property-label sensitivity, influence checks and internal host-level cross-validation
are now implemented. Read the [training regression report](reports/modeling/training_report.md)
for the earlier computed findings and limitations. That report and the pre-fit
protocol describe their historical stages, when test errors were still unscored.
They are preserved rather than rewritten after testing. The final report above
supersedes their next-step/status statements. The five-page Project Description
preserves the proposal-stage content and is not the final modeling report.

## Reproduce

### Course submission: one R file

Submit the report PDF and [Airbnb_Project.R](reports/submission/Airbnb_Project.R)
as separate files on Canvas. The course does not accept ZIP submissions.
This self-contained, readable R script includes all analytical code and the
configuration it needs; no repository checkout or other script is required.
Open it in RStudio and click **Source**, or run:

```sh
Rscript --vanilla Airbnb_Project.R
```

Use R 4.0 or newer and a writable working directory. On first run, internet
access is needed for the fixed Inside Airbnb dataset and any missing R packages
(`ggplot2`, `jsonlite`, `sandwich`). Outputs are created in
`airbnb_submission_output/` under the working directory. The optional `ragg`
package improves PNG rendering; numerical results do not depend on it.
The script rebuilds the analyses, report figures, tables and report text in R;
the separately supplied PDF is already typeset. Python is not needed to run
the submitted R analysis. Historical integrity records are recreated from
embedded plain text; numerical outputs are still recomputed from raw data.

### Development repository and document rendering

For the final analysis, install the R packages `ggplot2`, `jsonlite` and
optionally `ragg`, then run from the repository root:

```sh
Rscript --vanilla scripts/setup_model_dependencies.R
Rscript --vanilla scripts/run_final_analysis.R
python3 -m pip install -r requirements-report.txt
python3 scripts/18_build_final_report.py
python3 scripts/20_validate_final_report.py
python3 scripts/21_package_code.py
```

This rebuilds the fixed-source audit, four EDA figures, training review, frozen
model verification, reserved evaluation and final report. Repeated evaluations
are deterministic reproductions of the same frozen prediction rule, not new
model searches. The freeze step stops if the model, split, coefficients or
selection-code fingerprints change. Do not edit the lock to bypass that check
after viewing test errors. The renderer uses only the R-generated payload.

The earlier ZIP is a development backup, not the course submission format.
Add the real team roster to `config/team.csv` and rebuild to populate the
report author line; this does not change the fitted model. Regenerate the
single-file R submission with `python3 scripts/22_build_single_file_submission.py`
after changes to its source modules or team configuration.

### Individual earlier stages

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

To reproduce the complete training regression stage (requires the plotting
packages above):

```sh
Rscript --vanilla scripts/setup_model_dependencies.R
Rscript --vanilla scripts/12_training_report.R
Rscript --vanilla scripts/13_verify_training.R
```

The setup script installs `sandwich` and its dependencies into a local ignored
`.r-library/` when not already available. The report entry point regenerates the
audit, model samples, M0-M3 fits, six modeling figures and all modeling tables
from the pinned raw file. It uses training records only for fitting and internal
validation. It does not score the reserved test sample. Fitted objects are local
regenerable caches in ignored `models/`. The verifier checks clustered covariance
against a separate matrix calculation, compares coefficient contrasts with
predicted differences, and checks host isolation and internal validation records.

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
- `scripts/09_fit_training_models.R`: fit the starting M0-M2 models and property-label sensitivity; host-cluster inference and influence checks.
- `scripts/10_training_diagnostics.R`: generate starting-model diagnostic and association figures.
- `config/model_refinement.R`: record the single diagnostic-driven M3 refinement and training-host CV settings.
- `scripts/11_refine_training_model.R`: fit M3, compare training-host CV errors, repeat sensitivity and influence analysis.
- `scripts/12_training_report.R`: regenerate the complete training stage and its written report.
- `scripts/13_verify_training.R`: independently check covariance algebra, contrasts, CV accounting and host isolation.
- `scripts/setup_model_dependencies.R`: install model dependencies locally.
- `scripts/14_complete_training_review.R`: one final slope candidate, joint support and host influence review, using training data only.
- `scripts/15_freeze_final_model.R`: write or verify the immutable pre-evaluation model lock.
- `scripts/16_evaluate_reserved_hosts.R`: score the locked training fit without any model fitting.
- `scripts/17_prepare_final_report.R`: complete analysis and report payload with print-sized R figures.
- `scripts/18_build_final_report.py`: render the final payload to DOCX and PDF.
- `scripts/19_verify_final_analysis.R`: independent prediction algebra, covariance and error accounting checks.
- `scripts/20_validate_final_report.py`: validate final document content against the R payload and figures.
- `scripts/21_package_code.py`: produce the separate reproducible code archive.
- `scripts/22_build_single_file_submission.py`: inline the verified R analysis into one self-contained `.R` submission.
- `scripts/23_audit_price_quotes.R`: verify nightly quote agreement, quote dates and stay durations directly from the pinned raw data.
- `reports/submission/Airbnb_Project.R`: the single R file to upload with the report PDF; no ZIP required.
- `scripts/run_final_analysis.R`: organized R entry point for final analysis and numerical verification.
- `config/team.csv`: team names/UNIs, currently a blank header awaiting real information.
- `data/raw/`: unmodified compressed source data, local only.
- `data/processed/`: reproducible scoped records and preliminary EDA sample, local only.
- `reports/audit/`: generated aggregate CSVs, audit narrative and R session details.
- `reports/eda/`: generated descriptive statistics, coverage checks, figure inputs and EDA narrative.
- `reports/model_preparation/`: generated sample-flow, split-count and modeling-protocol files.
- `reports/project_description/`: generated five-page initial report and its text/data payload.
- `reports/modeling/`: generated training-model summaries, coefficients, tests, diagnostics, CV results and written report.
- `reports/final_analysis/`: final selection, support, influence, locked-model summaries, test errors and verification results.
- `reports/final_report/`: final report, payload, document validation and separate code archive.
- `figures/`: four exploratory PNG plots and six additional training-model figures in `figures/modeling/`.
- `docs/requirements.md`: course deliverables and implementation checklist.
- `docs/analysis_plan.md`: proposed questions, cleaning decisions and next steps.
- `docs/data_source.md`: provenance, attribution and field interpretation.

Do not manually edit generated reports, statistics or figures; change the code and rerun it.

## Next milestone

Add real team names/UNIs, review the final report, and reconcile any additional
classroom instructions and final deadline. The statistical workflow is complete;
remaining residual patterns, population sensitivity and host influence are
reported limitations, not claims of fully satisfied assumptions. Earlier EDA
viewed the full snapshot, so the reserved evaluation is not pristine external
validation. Do not use its score to reopen model selection.

## Source attribution

Inside Airbnb. New York City detailed listings, snapshot labeled 2026-09-14.
Retrieved for this project on 2026-11-18. Public download:
https://insideairbnb.com/get-the-data/ . Data are provided under CC BY 4.0;
see `docs/data_source.md`. Inside Airbnb is independent of Airbnb.
