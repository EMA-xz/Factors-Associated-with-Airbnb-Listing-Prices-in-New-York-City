# Modeling sample protocol

Protocol version: 2026-11-18-v1. Recorded before any regression fitting.

## Eligibility and scope

Primary analysis retains both room types in both boroughs, including hotel-like property labels. Require finite positive price, integer accommodates >= 1, integer bedrooms >= 0, integer minimum_nights >= 1 and a known host ID. No arbitrary price trimming or imputation. Rating is not required or included in the core model.

The sensitivity sample uses the same requirements and excludes property_type strings matching hotel|hostel|resort (case-insensitive), plus unknown property types. This is a non-hotel-label subset, not a verified residential population. It retains Private room. These exclusions are fixed before model results are examined.

- Scoped listings: 23,440.
- Positive-price EDA sample: 14,646.
- Positive price and valid complete core covariates: 14,616.
- Primary sample with known host ID: 14,616.
- Sensitivity sample without hotel/hostel/resort text or unknown property type: 13,155.

## Fixed split

Sort unique host IDs, use R seed 20261118 with Mersenne-Twister/Inversion/Rejection, and select floor(0.8 * number of hosts) for training without replacement. The remaining hosts form the test set. This targets roughly 80% of hosts, not exactly 80% of listings. Each host stays in one partition; the sensitivity subset inherits that assignment.

- primary / test: 3,048 listings from 1,391 hosts.
- primary / train: 11,568 listings from 5,564 hosts.
- without_hotel_labels / test: 2,762 listings from 1,335 hosts.
- without_hotel_labels / train: 10,393 listings from 5,327 hosts.

The split has zero host overlap and both room types in each borough in both partitions. Do not redraw it in response to model performance. Row-level assignments are in the reproducible local data/processed/host_split.csv.

Earlier EDA viewed the entire snapshot, including future test records. This is a prospective holdout for subsequent model fitting and selection, not an untouched preregistered external test dataset. No test errors have been calculated. Do not use test outcomes for subsequent transformation selection, thresholds, model selection, or tuning.

## Candidate regressions

- M0: `log_price ~ borough + room_type`.
- M1: `log_price ~ borough + room_type + accommodates + bedrooms + log_minimum_nights + long_stay`.
- M2: `log_price ~ borough * room_type + accommodates + bedrooms + log_minimum_nights + long_stay`.

Reference levels are Brooklyn and Private room. log_minimum_nights is the natural log of the minimum stay; long_stay indicates minimum_nights >= 30. Together they allow a threshold shift plus variation with stay length. This is a starting specification, not a proven adequate model. Check rank, collinearity and residual form using training data. Document justified revisions before touching test errors; do not select by desired significance.

Fit all candidate models to the same primary training rows. For the property-label sensitivity, refit the final selected specification on the sensitivity training rows and compare the same borough/room-type contrasts. Do not separately search for a favorable sensitivity specification. Compare estimates and intervals, not only significance labels; the subset changes the target population.

## Subsequent analysis

No models are fitted in this preparation step. Future work: training-data diagnostics, influential observations, appropriate handling of host dependence/heteroskedasticity, interaction contrasts with confidence intervals, and MSPR on held-out hosts compared with training residual MSE on the log-price scale. Compute MSE with the residual degrees of freedom and report the validation sample sizes. Do not refit on test records before the required comparison.
