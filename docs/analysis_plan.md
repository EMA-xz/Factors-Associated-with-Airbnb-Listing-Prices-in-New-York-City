# Analysis plan (proposed, not empirical conclusions)

## Research questions

1. Do listing prices differ between Manhattan and Brooklyn after adjusting for observed listing characteristics?
2. Do prices differ between Entire home/apt and Private room within each borough after adjustment?
3. Does the room-type association differ by borough?

Candidate model: `log(price) ~ borough * room_type + accommodates + bedrooms + minimum_nights`.
Consider rating only after investigating its missingness. Transformations and
functional forms are provisional; inspect residual behavior rather than assuming
that a log histogram alone validates the model. With an interaction, state the
reference group and interpret the appropriate coefficient combinations.

## Current audit decisions

- Scope uses the two named boroughs and two exact room-type values.
- Unique listing IDs are required; duplicate IDs stop execution for investigation.
- The preliminary price EDA sample requires an observed, finite, positive price.
- No arbitrary cap on the number of records; no price-tail deletion or imputation.
- Core covariate and rating completeness are flags, not yet final inclusion rules.
- Missing prices and missing ratings are never converted to zero.
- Zero bedrooms may represent a studio; missing bedrooms are not assumed to be zero.
- Long numeric IDs are imported as strings to avoid precision loss.
- The source snapshot and its actual per-row scrape dates are recorded separately.

## Questions to resolve before final modeling

- Is price coverage different across borough/room-type and other observed characteristics?
- What distinguishes short minimum stays and minimum stays of 30+ nights across groups?
- Do the four groups have overlapping capacity/bedroom ranges sufficient for fair adjusted comparisons?
- Are there unusual property types or quote definitions that require clarification?
- Are extreme observations plausible, and do they materially change the conclusions?
- Are repeated hosts common enough to warrant host-grouped validation and clustered inference?
- Does adding ratings change the sample composition and conclusions?

The audit retains quote fields in the original source but does not substitute
them for missing `price`. The provider's older dictionary does not document all
newer quote fields; investigate them before making any such change.

## Planned first four figures (not yet generated)

1. Raw daily listing-price histogram, USD, with any display restriction disclosed.
2. Natural-log price histogram using the same price-eligible sample.
3. Log-price boxplot by borough and room type, with group sample sizes.
4. Accommodates versus log price, colored by room type and faceted by borough;
   use transparency and, if needed, a fixed seed for horizontal display jitter.

Plot 4 will explicitly disclose any additional exclusions for missing/invalid
accommodates. It represents four variables and addresses the multidimensional
graphic request without requiring a 3D chart.

## Later validation

Choose a held-out test split before data-driven model selection; consider grouping
by host. Keep all learned preprocessing within training data. Compare test MSPR
with training residual MSE on the log-price scale; specify the MSE degrees of
freedom. Do not repeatedly tune against the held-out test set. Inspect residuals,
variance, collinearity, leverage and Cook's distance. Report effect sizes and
confidence intervals alongside tests. Interpret associations, not causal effects.
