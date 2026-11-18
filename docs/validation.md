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
No inferential model has yet been fitted or validated.

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
checks do not establish statistical-model validity; no regression is fitted yet.
