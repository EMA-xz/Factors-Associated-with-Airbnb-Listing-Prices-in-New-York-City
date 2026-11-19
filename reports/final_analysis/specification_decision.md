# Final specification fixed before reserved-host evaluation

Decision date: 2026-11-19. This record describes the pre-evaluation decision; later test scores are stored separately.

Selected model: M3
Formula: `log_price ~ borough * room_type + log_accommodates + bedrooms + within_stay_log_min + long_stay`.

M4 allowed the log-capacity slope to vary by room type. Its listing-weighted CV MSE improved by 0.128% and equal-host MSE by 0.844% relative to M3. Neither reached the previously recorded 1% adoption requirement, so retain M3. This is a pragmatic parsimony decision, not a significance test or claim that M3 predicts better than M4.

The original response, sample eligibility, both room types, host split and hotel-label sensitivity are unchanged. Retain the planned borough-by-room interaction to answer the research question, not because it is significant. The coefficient estimates and training-only stay centers are locked in config/final_model_lock.json.

There are 5 joint capacity-bedroom-stay-regime cells with at least 20 training records in every borough/room group. They cover 6728 training records (58.2%). Both stay regimes have observations at two-person capacity and one bedroom in all four groups. Marginal cell overlap does not prove joint overlap in exact minimum nights, neighborhood, amenities or other unmeasured characteristics.

Primary conditional comparisons are reported at capacity two, one bedroom and a common modeled minimum-stay condition. Under M3, borough/room contrasts do not depend on capacity; four-person comparisons are redundant and supplied only as a labeled secondary output. Common-slope assumptions remain approximations.

The largest absolute change in a primary log contrast after deleting any one of the ten largest hosts is 0.1066, versus 0.0017 after deleting the largest-Cook record. These are limited influence checks, not exhaustive leave-every-host-out validation. No case or host is deleted from the primary fit.

Residual upper tails, unequal spread and group-capacity patterns persist. Host-cluster covariance protects against some error dependence and heteroskedasticity, not mean misspecification. Treat coefficients as a parsimonious working log-price association model; do not claim all assumptions pass, precise market-wide conditional effects, or causality.

Reserved evaluation rule: use the saved training coefficients and centers for all eligible test hosts; compute mean squared log-price error and compare with training RSS/(n-p). Also report the training-mean intercept-only benchmark and group errors descriptively. Do not refit on test data, search alternatives using test scores, remove high-error test observations, or redraw the split. The earlier full-snapshot EDA limits the independence of this evaluation.
