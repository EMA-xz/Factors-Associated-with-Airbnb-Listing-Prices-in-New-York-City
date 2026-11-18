# Recorded before fitting any regression. Changes require a documented reason.
model_protocol_version <- "2026-11-18-v1"
split_seed <- 20261118L
training_host_fraction <- 0.80
excluded_property_pattern <- "hotel|hostel|resort"
reference_borough <- "Brooklyn"
reference_room_type <- "Private room"
candidate_formulas <- c(
  M0 = "log_price ~ borough + room_type",
  M1 = "log_price ~ borough + room_type + accommodates + bedrooms + log_minimum_nights + long_stay",
  M2 = "log_price ~ borough * room_type + accommodates + bedrooms + log_minimum_nights + long_stay"
)
