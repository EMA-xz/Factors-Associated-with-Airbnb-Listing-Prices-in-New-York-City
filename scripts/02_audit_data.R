source("scripts/01_download_data.R")
# Character import preserves long listing IDs exactly and retains source strings.
raw <- read.csv(gzfile(raw_path), colClasses = "character", check.names = FALSE,
                na.strings = c("", "NA"), stringsAsFactors = FALSE)
required <- c("id", "host_id", "last_scraped", "neighbourhood_group_cleansed",
              "room_type", "price", "accommodates", "bedrooms", "minimum_nights",
              "review_scores_rating")
if (length(setdiff(required, names(raw)))) stop("Required source fields are missing.")
missing <- function(x) is.na(x) | trimws(x) == ""
if (any(missing(raw$id)) || anyDuplicated(raw$id)) {
  stop("Missing or duplicate listing IDs: resolve explicitly before creating a sample.")
}
save_csv <- function(x, filename) {
  write.csv(x, file.path("reports/audit", filename), row.names = FALSE, na = "")
}
save_csv(data.frame(field = names(raw), missing_n = vapply(raw, function(x)
  sum(missing(x)), integer(1))), "all_fields.csv")
scope <- raw$neighbourhood_group_cleansed %in% c("Manhattan", "Brooklyn") &
  raw$room_type %in% c("Entire home/apt", "Private room")
d <- raw[scope, required]
names(d)[names(d) == "neighbourhood_group_cleansed"] <- "borough"
names(d)[names(d) == "price"] <- "price_raw"
numeric_fields <- c("accommodates", "bedrooms", "minimum_nights", "review_scores_rating")
parse_failures <- data.frame(field = character(), failed_nonmissing_n = integer())
for (field in numeric_fields) {
  original <- d[[field]]
  d[[field]] <- suppressWarnings(as.numeric(original))
  parse_failures <- rbind(parse_failures, data.frame(field = field,
    failed_nonmissing_n = sum(!missing(original) & is.na(d[[field]]))))
}
price_string <- gsub("[$,]", "", trimws(d$price_raw))
d$price <- suppressWarnings(as.numeric(price_string))
parse_failures <- rbind(parse_failures, data.frame(field = "price",
  failed_nonmissing_n = sum(!missing(d$price_raw) & is.na(d$price))))
save_csv(parse_failures, "parse_failures.csv")
d$price_observed <- !missing(d$price_raw)
d$valid_price <- is.finite(d$price) & d$price > 0
whole <- function(x) is.finite(x) & x == floor(x)
d$valid_core_covariates <- whole(d$accommodates) & d$accommodates >= 1 &
  whole(d$bedrooms) & d$bedrooms >= 0 &
  whole(d$minimum_nights) & d$minimum_nights >= 1
d$valid_rating <- is.finite(d$review_scores_rating) &
  d$review_scores_rating >= 0 & d$review_scores_rating <= 5
d$log_price <- NA_real_
d$log_price[d$valid_price] <- log(d$price[d$valid_price])
eda <- d[d$valid_price, ]
stopifnot(nrow(eda) > 0, all(is.finite(eda$log_price)))
write.csv(d, "data/processed/scoped_listings_with_flags.csv", row.names = FALSE, na = "")
write.csv(eda, "data/processed/eda_positive_price.csv", row.names = FALSE, na = "")
flow <- data.frame(stage = c("Raw NYC snapshot", "Two boroughs and two room types",
  "Observed finite positive price (preliminary EDA sample)",
  "Also valid complete core covariates (candidate, not final model sample)",
  "Also valid observed rating (candidate sensitivity sample)"),
  n = c(nrow(raw), nrow(d), nrow(eda), sum(d$valid_price & d$valid_core_covariates),
    sum(d$valid_price & d$valid_core_covariates & d$valid_rating)))
save_csv(flow, "sample_flow.csv")
groups <- split(d, interaction(d$borough, d$room_type, drop = TRUE))
group_audit <- do.call(rbind, lapply(groups, function(g) {
  p <- g$price[g$valid_price]
  data.frame(borough = g$borough[1], room_type = g$room_type[1], scoped_n = nrow(g),
    missing_price_n = sum(!g$price_observed), valid_price_n = length(p),
    valid_price_pct = 100 * mean(g$valid_price),
    core_complete_n = sum(g$valid_price & g$valid_core_covariates),
    rating_missing_in_eda_n = sum(g$valid_price & is.na(g$review_scores_rating)),
    median_price_usd = if(length(p)) median(p) else NA_real_,
    minimum_nights_ge30_in_eda_n = sum(g$valid_price & g$minimum_nights >= 30, na.rm = TRUE))
}))
rownames(group_audit) <- NULL
stopifnot(sum(group_audit$scoped_n) == nrow(d), sum(group_audit$valid_price_n) == nrow(eda))
save_csv(group_audit, "group_audit.csv")
fields <- c("price", numeric_fields)
missingness <- do.call(rbind, lapply(list(scoped = d, positive_price = eda), function(g) {
  data.frame(field = fields, n = nrow(g),
    missing_n = vapply(g[fields], function(x) sum(is.na(x)), integer(1)))
}))
missingness$sample <- rep(c("scoped", "positive_price"), each = length(fields))
rownames(missingness) <- NULL
save_csv(missingness, "missingness.csv")
numeric_summary <- do.call(rbind, lapply(fields, function(field) {
  x <- eda[[field]]; x <- x[is.finite(x)]
  q <- if(length(x)) unname(quantile(x, c(0, .25, .5, .75, .99, 1))) else rep(NA_real_, 6)
  data.frame(field = field, observed_n = length(x), mean = if(length(x)) mean(x) else NA_real_,
    sd = if(length(x)>1) sd(x) else NA_real_, min = q[1], q25 = q[2],
    median = q[3], q75 = q[4], q99 = q[5], max = q[6])
}))
save_csv(numeric_summary, "numeric_summary_positive_price.csv")
known_host <- !missing(eda$host_id)
host_sizes <- table(eda$host_id[known_host])
host_audit <- data.frame(known_hosts_n = length(host_sizes),
  hosts_with_multiple_scoped_priced_listings_n = sum(host_sizes > 1),
  listings_from_those_hosts_n = sum(host_sizes[host_sizes > 1]),
  max_scoped_priced_listings_per_host = if(length(host_sizes)) max(host_sizes) else NA_integer_,
  listings_missing_host_id_n = sum(!known_host))
save_csv(host_audit, "host_audit.csv")
save_csv(as.data.frame(table(raw$last_scraped), responseName = "n"), "scrape_dates.csv")
source_manifest <- data.frame(provider = "Inside Airbnb", snapshot_label = snapshot_date,
  observed_scrape_min = min(raw$last_scraped, na.rm=TRUE),
  observed_scrape_max = max(raw$last_scraped, na.rm=TRUE), url = source_url,
  local_file = raw_path, bytes = file.info(raw_path)$size,
  md5 = unname(tools::md5sum(raw_path)), sha256_at_acquisition = source_sha256,
  raw_rows = nrow(raw), raw_columns = ncol(raw))
save_csv(source_manifest, "source_manifest.csv")
fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
lines <- c("# Data audit: NYC Airbnb", "",
  "Generated by `Rscript --vanilla scripts/02_audit_data.R`; do not edit numerical results by hand.", "",
  paste0("Source: Inside Airbnb; snapshot label ", snapshot_date, "."),
  paste0("Observed scraping dates: ", source_manifest$observed_scrape_min, " to ", source_manifest$observed_scrape_max, "."),
  paste0("Raw file: ", fmt(nrow(raw)), " listings and ", ncol(raw), " fields; listing IDs are unique and nonmissing."), "",
  "## Sample accounting", "",
  paste0("- ", flow$stage, ": ", fmt(flow$n), "."), "",
  paste0("Missing price in scope: ", fmt(sum(!d$price_observed)), " (",
    sprintf("%.1f", 100*mean(!d$price_observed)), "% of scoped listings)."),
  paste0("Observed but nonfinite/nonpositive/unparseable prices: ",
    sum(d$price_observed & !d$valid_price), "."), "",
  "## Four-group coverage", "",
  vapply(seq_len(nrow(group_audit)), function(i) {
    g <- group_audit[i, ]
    paste0("- ", g$borough, " / ", g$room_type, ": ", fmt(g$scoped_n),
      " scoped; ", fmt(g$valid_price_n), " positive-price listings (",
      sprintf("%.1f", g$valid_price_pct), "%); median observed positive price $",
      sprintf("%.2f", g$median_price_usd), ".")
  }, character(1)), "", "## Decisions and limits", "",
  "- This is a preliminary EDA sample, not a finalized regression sample.",
  "- No price trimming, winsorization, imputation, random subsampling, or model fitting was performed.",
  "- Missing prices are not replaced by zero or another price-quote field. Coverage must be discussed before inference.",
  "- Bedrooms equal to zero are allowed; missing bedrooms are not assumed to mean a studio.",
  "- Missing ratings are retained in the scoped and EDA datasets; a rating is not required for EDA.",
  paste0("- ", fmt(sum(eda$minimum_nights >= 30, na.rm = TRUE)), " of ", fmt(nrow(eda)),
    " positive-price listings have minimum_nights >= 30; do not describe this sample as exclusively short stays."),
  paste0("- ", fmt(host_audit$hosts_with_multiple_scoped_priced_listings_n),
    " known hosts have multiple scoped positive-price listings, accounting for ",
    fmt(host_audit$listings_from_those_hosts_n), " listings; assess dependence before model inference/splitting."),
  "- Comparisons are observational associations in this snapshot, not causal effects or realized transaction prices.",
  "- Inspect missing-price selection, covariate overlap, and price semantics before finalizing the model.", "",
  "All detailed counts are in the adjacent CSV files. Row-level data are regenerated locally and excluded from Git.")
writeLines(lines, "reports/audit/data_audit.md")
writeLines(sub("[[:space:]]+$", "", capture.output(sessionInfo())),
           "reports/audit/session_info.txt")
cat(paste(lines, collapse = "\n"), "\n")
