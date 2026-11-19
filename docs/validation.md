# Execution verification

Verified on 2026-11-18 using the R version recorded in the generated session file.

1. Ran `Rscript --vanilla scripts/02_audit_data.R` against the acquired source file.
2. Copied only the scripts into an empty working directory.
3. Ran the same command there: the R downloader acquired the fixed remote file
   and passed its pinned checksum check, then regenerated the complete audit.
4. Compared every file in `reports/audit/` and both processed CSV files between
   the original run and fresh download run. All were byte-for-byte identical.

The pipeline also checks required fields, unique/nonmissing listing IDs, positive
finite prices for the EDA sample, finite log prices, and reconciliation between
four-group counts and sample totals. Parsing failures are recorded in a generated
CSV. This verifies acquisition/audit execution, not the validity of any future
regression model or statistical claim.

## Descriptive analysis and figures

The EDA entry point is `Rscript --vanilla scripts/04_generate_eda.R`.
It was run from the project and again in a separate clean output directory with
only the scripts and the pinned raw file supplied. The second run treated R
warnings as errors. Both runs completed successfully. Generated EDA CSVs,
Markdown report, session details, processed EDA data, and all four PNG images
were byte-for-byte identical in the same R/package/rendering environment.

Additional checks in the scripts reconcile group coverage, minimum-stay counts,
property-type counts and histogram-bin counts to their source samples. The figure
manifest records per-figure inclusion counts. All four PNGs were visually
inspected for labels, legends, clipping, source captions and display exclusions.
At that EDA stage, no inferential model had been fitted or validated.

## Project Description and model preparation

The full pipeline was run with R warnings treated as errors:

```sh
Rscript --vanilla -e 'options(warn=2); source("scripts/06_prepare_project_description.R")'
python3 scripts/07_build_project_description.py
python3 scripts/08_validate_project_outputs.py
```

It was repeated in an independent directory containing only the scripts, config
and the fixed raw snapshot. Model preparation outputs, primary/sensitivity data,
host assignments, report payload, Markdown, DOCX, PDF and validation output were
byte-for-byte identical in the same runtime. The deterministic host split is
created before any regression fitting. The independent output validator checks
host isolation, exact sensitivity-subset consistency, all group/partition counts,
the raw SHA-256, the report text/tables and original embedded figure hashes.

The standalone PDF and a separately rendered DOCX each contain five pages. Every
page in both versions was visually inspected for clipping, overflow, table
readability, figure labeling and page order. The DOCX was rendered with the
bundled document renderer; the standalone PDF was rasterized using Poppler with
a local writable font cache. No visual QA intermediates are included in Git.

Team names and UNIs have not been supplied. The blank roster is recorded as
incomplete in report_payload.json and validation.json. Fill config/team.csv with
the real 3-5 members and rebuild before submission. Rendering and integrity
checks do not establish statistical-model validity. Those documents preserve the
pre-regression proposal stage; subsequent model work is documented separately.

## Training regression stage

The complete training pipeline and separate verifier were run successfully with
warnings treated as errors:

```sh
Rscript --vanilla -e 'options(warn=2); source("scripts/12_training_report.R"); source("scripts/13_verify_training.R")'
```

The verifier passed 28 checks. These include comparing `sandwich::vcovCL` with
an independent host-score matrix calculation, checking conditional contrasts
against prediction differences, validating interval transformations, checking
the one-degree-of-freedom Wald/t identity, and confirming host/fold isolation
and one validation prediction per training listing per candidate model.

The command was repeated in a separate directory supplied only with committed
scripts/configuration and the fixed raw file, using the same installed R/package
environment. All 44 compared files were byte-for-byte identical: the modeling
reports and six figures, primary/sensitivity model data, host split, training
folds, internal-validation errors and M3 row-level diagnostics. Reproducibility
across different rendering environments may differ at the pixel level. All six
modeling figures were visually inspected; captions and intervals were checked.
The earlier report's 79 integrity checks also still pass.

These checks verify execution and numerical consistency, not full satisfaction
of regression assumptions. Residual tail/scale patterns, population sensitivity
and host concentration remain documented limitations. The reserved test hosts
have not been scored, and the final course report has not been assembled.

## Final model and report verification on 2026-11-19

The earlier entries describe their historical stages. The final model is now
frozen and the reserved evaluation is complete. Commit `26e8ecf` recorded the
model lock and decision before the first execution of the evaluation script.
M3 is retained after the last training-only candidate failed the recorded
adoption threshold. No specification change followed test scoring.

Executed `Rscript --vanilla scripts/run_final_analysis.R` with warnings treated
as errors. The 28 existing training checks and 27 final checks passed. The final
checks independently reconstruct predictions from locked coefficients, verify
host isolation and exact test coverage, recompute MSPR and training MSE with
their correct denominators, check the baseline and group accounting, and verify
cluster covariance, contrasts, the model lock and selection-code fingerprints.

The PDF/Word renderer and `scripts/20_validate_final_report.py` passed 41 document
checks: ten PDF pages, nine explicit DOCX page breaks, page-by-page report text
and tables matching the R payload, original embedded figure hashes and source/
model fingerprints. The standalone PDF and separately rendered DOCX each have
ten pages. Every page was visually inspected for clipping, readability, tables,
figure labels and page order; a clipped Cook-axis tick was corrected in plot code.
Multi-guide plots explicitly order their color and size legends in the final
rendering entry point; unspecified guide ordering initially caused image-only
reproduction differences even though all numerical results agreed.

The final pipeline was run independently in a directory containing only code,
configuration and the pinned raw data, with the same runtime/package library.
All 42 compared final-analysis, final-report, figure, lock and prediction/CV
files were byte-identical. Repeated scoring reproduces the same frozen rule;
it is not further tuning. The separate code ZIP excludes raw/processed records,
fitted caches and installed libraries and passes archive integrity checks.

The final report documents incomplete model assumptions, population sensitivity,
host influence and the limited independence of a holdout viewed during earlier
EDA. Team names/UNIs remain absent and are explicitly marked incomplete in the
payload and validation record; the team must supply them and review the report
before submission. Numerical checks are not a claim that statistical assumptions
hold or that classroom-specific requirements have been independently approved.
