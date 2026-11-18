# Rebuild the audited sample from the pinned raw snapshot; never rely on hand edits.
source("scripts/02_audit_data.R")
dir.create("reports/eda", recursive = TRUE, showWarnings = FALSE)
eda_csv <- function(x, name) write.csv(x, file.path("reports/eda", name),
                                     row.names = FALSE, na = "")
safe_median <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
d$borough <- factor(d$borough, c("Brooklyn", "Manhattan"))
d$room_type <- factor(d$room_type, c("Entire home/apt", "Private room"))
d$price_status <- ifelse(d$valid_price, "Observed positive price", "No usable price")
d$stay_group <- ifelse(!whole(d$minimum_nights) | d$minimum_nights < 1,
                       "Missing/invalid", ifelse(d$minimum_nights >= 30, "30+ nights", "1-29 nights"))
d$property_type <- raw$property_type[scope]
d$property_type[is.na(d$property_type) | d$property_type == ""] <- "Missing"
# Descriptive string rule, not a legal or verified business classification.
d$hotel_like_label <- grepl("hotel|hostel|resort", d$property_type, ignore.case=TRUE)
eda <- d[d$valid_price, ]
group_summary <- function(data, fields, fun) {
  pieces <- split(data, interaction(data[fields], drop = TRUE, lex.order = TRUE))
  out <- do.call(rbind, lapply(pieces, function(g) {
    result <- fun(g)
    keys <- g[rep(1, nrow(result)), fields, drop = FALSE]
    rownames(keys) <- NULL
    rownames(result) <- NULL
    cbind(keys, result)
  }))
  rownames(out) <- NULL
  out
}
coverage <- group_summary(d, c("borough", "room_type"), function(g) data.frame(
  scoped_n = nrow(g), observed_positive_n = sum(g$valid_price),
  missing_price_n = sum(!g$price_observed), unusable_price_n = sum(!g$valid_price),
  missing_price_pct = 100 * mean(!g$price_observed),
  positive_price_pct = 100 * mean(g$valid_price)))
eda_csv(coverage, "price_coverage_by_group.csv")
stay <- group_summary(d, c("borough", "room_type", "price_status", "stay_group"),
  function(g) data.frame(n = nrow(g)))
denom <- aggregate(n ~ borough + room_type + price_status, stay, sum)
names(denom)[4] <- "status_group_n"
stay <- merge(stay, denom, by = c("borough", "room_type", "price_status"), sort = TRUE)
stay$within_status_pct <- 100 * stay$n / stay$status_group_n
eda_csv(stay, "minimum_stay_by_price_status.csv")
selection <- group_summary(d, c("borough", "room_type", "price_status"), function(g) data.frame(
  n = nrow(g), accommodates_observed_n = sum(is.finite(g$accommodates)),
  accommodates_median = safe_median(g$accommodates), bedrooms_observed_n = sum(is.finite(g$bedrooms)),
  bedrooms_median = safe_median(g$bedrooms), minimum_nights_observed_n = sum(is.finite(g$minimum_nights)),
  minimum_nights_median = safe_median(g$minimum_nights),
  rating_observed_n = sum(is.finite(g$review_scores_rating)),
  rating_missing_pct = 100 * mean(is.na(g$review_scores_rating))))
eda_csv(selection, "observed_characteristics_by_price_status.csv")
describe <- function(g) {
  do.call(rbind, lapply(c("price", "log_price", "accommodates", "bedrooms", "minimum_nights", "review_scores_rating"), function(v) {
    z <- g[[v]]; z <- z[is.finite(z)]
    q <- if(length(z)) unname(quantile(z, c(0, .25, .5, .75, 1))) else rep(NA_real_,5)
    data.frame(variable = v, sample_n = nrow(g), observed_n = length(z), missing_n = nrow(g)-length(z),
      mean = if(length(z)) mean(z) else NA_real_, sd = if(length(z)>1) sd(z) else NA_real_,
      min = q[1], q25 = q[2], median = q[3], q75 = q[4], max = q[5])
  }))
}
overall <- describe(eda)
eda_csv(overall, "descriptive_overall.csv")
by_group <- group_summary(eda, c("borough", "room_type"), describe)
eda_csv(by_group, "descriptive_by_group.csv")
stay_prices <- group_summary(eda, c("borough", "room_type", "stay_group"), function(g) data.frame(
  n = nrow(g), median_price_usd = median(g$price), q25_price_usd = unname(quantile(g$price,.25)),
  q75_price_usd = unname(quantile(g$price,.75))))
eda_csv(stay_prices, "price_by_group_and_minimum_stay.csv")
# Exact counts expose sparse covariate combinations; no extrapolation is attempted.
capacity <- group_summary(eda, c("borough", "room_type", "accommodates"), function(g)
  data.frame(n = nrow(g), median_log_price = median(g$log_price)))
eda_csv(capacity, "capacity_support.csv")
bedroom_support <- group_summary(eda, c("borough", "room_type", "bedrooms"), function(g) data.frame(n=nrow(g)))
eda_csv(bedroom_support, "bedroom_support.csv")
# Property types are descriptive only: no hotel-like records are silently removed.
property <- data.frame(borough = raw$neighbourhood_group_cleansed[scope], room_type = raw$room_type[scope],
  property_type = raw$property_type[scope], price_status = d$price_status)
stopifnot(nrow(property) == nrow(d))
property$property_type[is.na(property$property_type) | property$property_type == ""] <- "Missing"
property_counts <- group_summary(property, c("borough", "room_type", "price_status", "property_type"), function(g) data.frame(n=nrow(g)))
eda_csv(property_counts, "property_type_composition.csv")
hotel_summary <- group_summary(eda, c("borough", "room_type"), function(g) data.frame(
  n=nrow(g), hotel_like_label_n=sum(g$hotel_like_label),
  hotel_like_label_pct=100*mean(g$hotel_like_label), missing_property_type_n=sum(g$property_type=="Missing")))
eda_csv(hotel_summary,"hotel_like_labels_by_group.csv")
hotel_stay <- group_summary(eda,c("borough","room_type","stay_group","hotel_like_label"),function(g)
  data.frame(n=nrow(g),median_price_usd=median(g$price)))
eda_csv(hotel_stay,"price_by_stay_and_hotel_label.csv")
eda_csv(unique(eda[,c("property_type","hotel_like_label")]),"property_label_classification.csv")
stopifnot(sum(coverage$scoped_n) == nrow(d), sum(coverage$observed_positive_n) == nrow(eda),
          sum(stay$n) == nrow(d), sum(stay_prices$n) == nrow(eda),
          sum(property_counts$n) == nrow(d))
write.csv(eda, "data/processed/eda_with_stay_groups.csv", row.names=FALSE, na="")
