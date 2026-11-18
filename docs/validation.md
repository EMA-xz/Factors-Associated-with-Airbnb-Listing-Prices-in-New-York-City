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
