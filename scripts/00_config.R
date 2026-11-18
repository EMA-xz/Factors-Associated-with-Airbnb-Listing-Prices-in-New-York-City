# Run scripts from the repository root. No external R packages are required.
snapshot_date <- "2026-09-14"
source_url <- paste0("https://data.insideairbnb.com/united-states/ny/",
                     "new-york-city/", snapshot_date, "/data/listings.csv.gz")
raw_path <- file.path("data", "raw", paste0("nyc_listings_", snapshot_date, ".csv.gz"))
# Fingerprint of the actual downloaded file; reject silently changed snapshots.
expected_md5 <- "d246ef4c52a914b514419cb5839dd9d7"
source_sha256 <- "a67bf574e47aa6eba5b2262987dbd9684f206d5cd0183470056f9c936b8e7ae1"
for (folder in c("data/raw", "data/processed", "reports/audit")) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}
