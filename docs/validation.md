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
CSV. This verifies the current acquisition/audit stage, not the validity of any
future regression model or statistical claim.
