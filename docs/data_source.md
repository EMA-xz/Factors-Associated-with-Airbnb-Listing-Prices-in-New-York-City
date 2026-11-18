# Data provenance and interpretation

Provider: Inside Airbnb (independent of Airbnb).

- Source index: https://insideairbnb.com/get-the-data/
- Snapshot label: 2026-09-14, New York City detailed listings.
- File: https://data.insideairbnb.com/united-states/ny/new-york-city/2026-09-14/data/listings.csv.gz
- Acquisition date for this project: 2026-11-18.
- Attribution/license: CC BY 4.0, as stated on the provider's download page.
- Provider assumptions: https://insideairbnb.com/data-assumptions/
- Provider dictionary: https://docs.google.com/spreadsheets/d/1iWCNJcSutYqpULSQHlNyGInUvHg2BoUGoNRIGa6Szc4/edit

The generated `reports/audit/source_manifest.csv` records the file URL, bytes,
checksums, shape and observed scrape-date range. Snapshot labels need not equal
every listing's actual scrape date. Retain the original compressed file locally;
do not edit it or silently replace it with a newer snapshot.

## Fields used in the initial audit

- `id`: listing identifier, preserved as text.
- `host_id`: host identifier, preserved as text, for repeated-host checks.
- `last_scraped`: actual listing scrape date.
- `neighbourhood_group_cleansed`: borough grouping; renamed `borough` in derived data.
- `room_type`: room category; retain exact source labels.
- `price`: daily listing price in local currency per the provider dictionary;
  NYC prices are interpreted in USD. Remove formatting characters to parse the
  field, retaining its original string. This is not an observed transaction price.
- `accommodates`: maximum listing capacity.
- `bedrooms`: number of bedrooms.
- `minimum_nights`: listing minimum stay; calendar-specific rules may differ.
- `review_scores_rating`: overall review score; missing is distinct from zero.

The linked dictionary identifies itself as version 4.3 (August 2022) and does not
describe every newer column in this snapshot, including the additional price-quote
fields. Those fields are not used to fill missing prices in this initial pipeline.

Data limitations include missing values, observational selection, a single
snapshot, and potentially dependent listings from the same host. Source-page
availability alone is not evidence that a listing was actually booked.
