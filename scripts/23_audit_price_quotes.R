# Audit response measurement; no model, sample rule or prediction is changed.
# The snapshot's quote fields describe a dated quote, not a realized booking.
price_quote_audit <- local({
  source("scripts/01_download_data.R")
  x <- read.csv(gzfile(raw_path), colClasses="character", check.names=FALSE,
                na.strings=c("", "NA"), stringsAsFactors=FALSE)
  fields <- c("id", "neighbourhood_group_cleansed", "room_type", "price",
              "minimum_nights", "price_quote_price_per_night",
              "price_quote_checkin_date", "price_quote_checkout_date", "price_quote_raw")
  stopifnot(all(fields %in% names(x)))
  number <- function(v) suppressWarnings(as.numeric(gsub("[$,]", "", trimws(v))))
  price <- number(x$price)
  keep <- x$neighbourhood_group_cleansed %in% c("Brooklyn", "Manhattan") &
    x$room_type %in% c("Private room", "Entire home/apt") & is.finite(price) & price>0
  a <- x[keep, fields]; price <- price[keep]
  quoted <- number(a$price_quote_price_per_night)
  comparable <- is.finite(quoted)
  # Compare monetary fields at their supplied cent precision, not binary decimals.
  equal <- comparable & round(price*100)==round(quoted*100)
  checkin <- as.Date(a$price_quote_checkin_date, format="%Y-%m-%d")
  checkout <- as.Date(a$price_quote_checkout_date, format="%Y-%m-%d")
  nights <- as.integer(checkout-checkin)
  valid_dates <- !is.na(nights) & nights>0
  # Inspect quote metadata without treating missing discount information as zero.
  discount <- vapply(a$price_quote_raw, function(s) {
    if(is.na(s) || !nzchar(trimws(s))) return(NA_real_)
    q <- jsonlite::fromJSON(s, simplifyVector=FALSE)$quote
    if(is.null(q$discount_amount)) return(NA_real_)
    number(q$discount_amount)
  }, numeric(1))
  out <- data.frame(eda_n=nrow(a), quote_amount_observed_n=sum(comparable),
    price_matches_quote_at_cent_precision_n=sum(equal),
    price_differs_from_quote_n=sum(comparable & !equal),
    quote_amount_missing_n=sum(!comparable),
    valid_quote_dates_n=sum(valid_dates),
    matching_price_with_valid_quote_dates_n=sum(equal & valid_dates),
    quoted_stay_ge30_n=sum(valid_dates & nights>=30,na.rm=TRUE),
    quoted_stay_ge30_pct_of_eda=100*sum(valid_dates & nights>=30,na.rm=TRUE)/nrow(a),
    minimum_requirement_ge30_n=sum(number(a$minimum_nights)>=30,na.rm=TRUE),
    explicit_positive_discount_n=sum(discount>0,na.rm=TRUE))
  stopifnot(out$quote_amount_observed_n+out$quote_amount_missing_n==out$eda_n,
            out$price_matches_quote_at_cent_precision_n+out$price_differs_from_quote_n==out$quote_amount_observed_n,
            out$matching_price_with_valid_quote_dates_n<=out$valid_quote_dates_n)
  write.csv(out,"reports/audit/price_quote_measurement.csv",row.names=FALSE)
  mismatches <- data.frame(id=a$id[comparable & !equal], price=price[comparable & !equal],
                           quote_per_night=quoted[comparable & !equal])
  write.csv(mismatches,"reports/audit/price_quote_mismatches.csv",row.names=FALSE)
  out
})
print(price_quote_audit)
