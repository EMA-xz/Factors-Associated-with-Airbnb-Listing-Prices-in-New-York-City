# Recorded before fitting M4 or viewing any reserved test errors, 2026-11-19.
# M3 residual-capacity patterns differ between room types. Test one additional
# slope interaction, with capacity centered at two guests for interpretable contrasts.
completion_candidate_formula <- "log_price ~ borough * room_type + room_type * log_capacity_2 + bedrooms + within_stay_log_min + long_stay"
capacity_reference <- 2
# Use the SAME saved training-host folds. Adopt M4 only if both listing-weighted
# and equal-host CV MSE improve by at least 1%, with full rank in all fits.
# This is a pragmatic complexity threshold, not a significance test or unbiased CV.
minimum_relative_CV_improvement <- .01
# Main conditional room-type comparisons will be at capacity=2. Comparisons at
# capacity=4 are secondary, explicitly labeled, with support counts disclosed.
# No further functional-form search is planned before the reserved evaluation.
