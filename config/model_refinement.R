# Added after inspecting M2 TRAINING diagnostics, before evaluating M3 or any test errors.
# M2 mean residuals vary nonlinearly with capacity; a log-capacity candidate has
# the same parameter count. Stay centering is an equivalent reparameterization,
# not an improvement in fitted values or a cure for weak within-regime support.
refinement_formula <- "log_price ~ borough * room_type + log_accommodates + bedrooms + within_stay_log_min + long_stay"
training_cv_seed <- 20261119L
training_cv_folds <- 5L
