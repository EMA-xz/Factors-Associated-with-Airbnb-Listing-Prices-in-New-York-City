# Airbnb Listing Prices in Manhattan and Brooklyn

Project Description | STAT GU4205/GR5205 | Fall 2026

Team members and UNIs: __________________________________________________

## Study objectives

A private room and an entire apartment can differ in how many guests they accommodate and how long a guest must stay. We compare nightly prices in Manhattan and Brooklyn while accounting for guest capacity, bedrooms and minimum-stay requirements.

1. Do adjusted borough price differences persist within each room type?
2. Do adjusted room-type price differences persist within each borough?
3. Is the price gap between entire homes and private rooms larger in one borough than in the other?

## Data source and analytical sample

We use Inside Airbnb's September 2026 snapshot of 29,918 New York City listings [1]. Each observation represents one listing. Price is the nightly amount in US dollars quoted for the observation [2]. The amount can depend on the dates and length of the requested stay.

Manhattan and Brooklyn together have 23,440 entire-home and private-room listings. Of these, 8,794 (37.5%) have no recorded price. The price summaries cover all 14,646 listings with a positive observed price, including those with missing information on other characteristics.

## Daily price summaries in USD

| Borough and room type | n | Median | Mean | SD | Q1 to Q3 |
| --- | --- | --- | --- | --- | --- |
| Brooklyn Entire home/apt | 3,009 | $195.53 | $276.70 | $355.30 | $139.67 to $302.13 |
| Brooklyn Private room | 3,234 | $101.01 | $164.17 | $256.33 | $65.13 to $193.54 |
| Manhattan Entire home/apt | 5,506 | $254.54 | $411.00 | $685.04 | $175.13 to $450.71 |
| Manhattan Private room | 2,897 | $256.00 | $425.07 | $651.99 | $92.88 to $556.10 |

Q1 and Q3 are the 25th and 75th percentiles. These comparisons are unadjusted.

# Raw price distribution

Across the exploratory sample, the mean daily price is $331.69 and the median is $204.70. Prices range from $17.70 to $31,537.82, indicating a long upper tail that deserves attention in model diagnostics.

![01_raw_price_distribution.png](../../figures/01_raw_price_distribution.png)

The lower panel of Figure 1 shows prices through the 99th percentile, $2,000.00. The 146 higher-priced listings appear in the upper panel and contribute to the mean. The lower panel makes the distribution of more typical nightly prices easier to see.

# Price transformation and listing characteristics

![02_log_price_distribution.png](../../figures/02_log_price_distribution.png)

Figure 2 shows the same listings on a logarithmic scale. A doubling of price spans the same distance anywhere along this axis, which makes proportional differences easier to see. We will use log price to compare percentage differences between groups.

## Observed covariates in the exploratory sample

| Variable | Observed n | Missing n | Median | Q1 | Q3 |
| --- | --- | --- | --- | --- | --- |
| Guest capacity | 14,646 | 0 | 2.00 | 2.00 | 4.00 |
| Bedrooms | 14,622 | 24 | 1.00 | 1.00 | 2.00 |
| Minimum nights | 14,640 | 6 | 30.00 | 5.00 | 30.00 |
| Review score | 10,775 | 3,871 | 4.85 | 4.65 | 5.00 |

Capacity and bedrooms describe listing size, while minimum nights captures stay requirements. Review scores have substantial missingness and are not required in the planned core model. Missing bedrooms are not recoded as zero; a reported zero-bedroom listing is retained as a possible studio. Repeated listings from the same host will also be considered when evaluating dependence.

# Borough and room type comparisons

![03_price_by_borough_room_type.png](../../figures/03_price_by_borough_room_type.png)

Figure 3 compares unadjusted distributions. In Manhattan, median price is $256.00 for private rooms and $254.54 for entire homes. Among listings requiring at least 30 nights, the corresponding medians are $89.86 and $230.51. The ordering of the two room types changes within this subset, giving us a reason to account for minimum-stay requirements in the regression.

| Borough and room type | Price coverage | Minimum stay 30+ | Hotel like label |
| --- | --- | --- | --- |
| Brooklyn Entire home/apt | 56.6% | 86.7% | 0.1% |
| Brooklyn Private room | 66.6% | 69.9% | 3.1% |
| Manhattan Entire home/apt | 61.7% | 83.9% | 1.1% |
| Manhattan Private room | 66.6% | 46.9% | 45.0% |

Price coverage uses all scoped listings in that group. The other percentages use positive-price listings, including records with missing minimum stay in their denominators. Hotel like label means property_type contains hotel, hostel or resort, case-insensitively; it is not a verified business or legal classification.

Within Manhattan private rooms, 1,304 of 2,897 listings (45.0%) meet that label rule. We retain them in the primary scope and plan one sensitivity analysis excluding those labels and unknown property types. Private room itself is retained in both analyses.

# Capacity relationships and planned analysis

![04_capacity_price_multidimensional.png](../../figures/04_capacity_price_multidimensional.png)

Figure 4 shows how nightly prices vary with guest capacity in each borough. Brooklyn: median capacity is 4 for entire homes and 2 for private rooms; Manhattan: median capacity is 3 for entire homes and 2 for private rooms. The difference in typical capacity motivates adjusting for listing size. The figure includes 14,646 listings. Diamonds mark medians for groups with at least 20 listings. Few private rooms accommodate large groups, so comparisons at high capacity are less informative.

## Planned regression and validation

Our starting specification models log price using borough, room type, their interaction, capacity, bedrooms, log minimum nights and an indicator for minimum stays of at least 30 nights. The model sample includes 14,616 listings with complete predictors and a known host. The comparison excluding hotel-like and unknown property labels includes 13,155. We will compare the borough and room-type estimates across these samples.

The figures describe the full sample. For regression, we will use about 80% of hosts for training and the rest for testing, keeping each host's listings together. We will examine residual patterns and influential listings, then compare prediction error for the held-out hosts with training error on the log-price scale.

Limitations include missing-price selection, differing property/stay composition, unmeasured listing characteristics and a single observational snapshot. Results will describe adjusted associations within the chosen sample, not causal effects or all NYC accommodation [3].

## References

[1] Inside Airbnb. New York City detailed listings, 2026-09-14. CC BY 4.0. https://insideairbnb.com/get-the-data/

[2] Inside Airbnb. Data Dictionary for detailed listings. https://docs.google.com/spreadsheets/d/1iWCNJcSutYqpULSQHlNyGInUvHg2BoUGoNRIGa6Szc4/edit

[3] Inside Airbnb. Data Assumptions. https://insideairbnb.com/data-assumptions/
