# Riyadh Housing Pipeline

A SQL data pipeline in **Google BigQuery** that turns raw Riyadh villa listings into a clean, tested star schema, then uses it to rank neighborhoods by price per square meter.

Built on the [Riyadh Villas dataset](https://www.kaggle.com/datasets/mohammadqahtani/riyadh-villas-dataset) (Aqar listings via Kaggle), the same data as my earlier [analysis notebook](https://github.com/) project, rebuilt here the way a data engineering team would: in the warehouse, repeatable, and tested.

## Pipeline

```
raw_listings (9,974)
      │  01_staging.sql: clean, fix, deduplicate
      ▼
stg_listings (9,597)
      │  03_dim_neighborhood.sql      04_fact_listings.sql
      ▼                               ▼
dim_neighborhood (124)  ◄──────  fact_listings (9,597)
```

| File | Builds | Purpose |
|---|---|---|
| `sql/01_staging.sql` | `stg_listings` | Cleaned copy of the raw data |
| `sql/02_quality_checks.sql` | — | 13 tests; run after every rebuild |
| `sql/03_dim_neighborhood.sql` | `dim_neighborhood` | One row per neighborhood, with an ID |
| `sql/04_fact_listings.sql` | `fact_listings` | One row per listing: size, price, bedrooms, bathrooms |
| `sql/05_analysis.sql` | — | Top 10 neighborhoods by price per m² |

**Run order:** 01 → 03 → 04 → 02. The fact table reads the dimension, so the dimension must be rebuilt first.

## Cleaning rules

Every rule in `01_staging.sql` comes from a problem found in the data:

- **Missing details:** listings with no description text are removed.
- **Size fix:** listing 8054 had a size of 450,000 m²; the listing text confirms 450.
- **Invalid listings:** two listings (217, 7436) are removed.
- **Neighborhood:** extracted from the location text (`حي الرمال - الرياض` → `حي الرمال`).
- **Missing-zero prices:** `price >= 200,000`. Villas listed at 85,000 to 185,000 had descriptions stating ten times that (e.g. 85,000 vs. "مطلوب ٨٥٠ الف").
- **Extra-zero prices:** `price / size <= 20,000`. Ordinary 300 to 500 m² villas listed at 8 to 17 million were priced like 10× typos; real luxury properties (1,200 to 6,000 m²) sit below this line.
- **Duplicates:** listings identical in neighborhood, size, price, bedrooms, bathrooms, and details are collapsed to one.

The price thresholds were set by inspecting the most extreme listings by hand and tracing them back to their description text, not by a percentile cutoff, which would have removed verified luxury listings.

In total, 377 rows are removed (3.8%): 322 by the first rules and duplicates, and 55 by the price rules.

## Quality checks

`02_quality_checks.sql` contains 13 checks, each with an expected value. All pass. They cover:

- **Row counts:** staging and fact tables match, and the rows removed equal the rows intended (377).
- **Uniqueness:** no duplicate listing IDs, listing groups, or neighborhood names.
- **Completeness:** no NULLs in key columns, and every listing matched a neighborhood.
- **Rules:** sizes and prices stay inside the cleaning rules.
- **Reconciliation:** every price in the fact table equals its staging value, listing by listing.

One principle guided all of them: **a check is only useful if it can fail.** Several early versions returned 0 no matter what (an impossible `AND` condition, an ID uniqueness test on IDs generated to be unique) and were rewritten.

## Result

Top 10 neighborhoods by price per m² (at least 10 listings each):

| # | Neighborhood | Listings | Price per m² (SAR) |
|---|---|---|---|
| 1 | حي حطين | 195 | 8,178 |
| 2 | حي الخزامى | 29 | 7,901 |
| 3 | حي النخيل | 41 | 6,829 |
| 4 | حي الملقا | 596 | 6,710 |
| 5 | حي عرقة | 27 | 6,576 |
| 6 | حي الندى | 45 | 6,248 |
| 7 | حي الغدير | 12 | 6,059 |
| 8 | حي النفل | 16 | 5,799 |
| 9 | حي التعاون | 12 | 5,593 |
| 10 | حي الملك عبدالله | 10 | 5,582 |

**The metric mattered more than the cleaning.** A first version using `AVG(price / size)` ranked حي الملك عبدالعزيز first at 23,849, driven by a single listing priced at 11,111,111 for 111 m². Switching to `SUM(price) / SUM(size)` halved that value even before cleaning, and a 10-listing minimum removed neighborhoods ranked on one listing. Most other neighborhoods' values barely changed after cleaning.

## Lessons

- **Reconcile against a known-good result.** I first cleaned this data in pandas, then rebuilt it in SQL. My first deduplication rule used the wrong key and silently deleted thousands of real rows; only comparing the row count against the notebook caught it.
- **Remove, don't guess.** A ×10 correction looked tempting, but listing 8344's text gave 1,050,000 where ×10 would give 1,000,500, so suspicious prices are removed rather than "fixed".
- **Use `LEFT JOIN` when building tables.** An `INNER JOIN` would silently drop unmatched listings; a `LEFT JOIN` turns them into NULLs that a check can catch.

## Limitations

- The price rules catch obvious typos, not every wrong price. An extra zero on a large villa can still land under 20,000 per m².
- Thresholds are tuned for Riyadh villas and would need revisiting for other cities or property types.
- Neighborhoods with 10 to 16 listings rank less reliably than those with hundreds.

## How to run

The dataset is not included in this repo. To reproduce the pipeline:

1. Download the [Riyadh Villas dataset](https://www.kaggle.com/datasets/mohammadqahtani/riyadh-villas-dataset) from Kaggle (villa listings scraped from Aqar).
2. In BigQuery, create a dataset named `riyadh` and load the CSV as a table named `raw_listings`.
3. Run the SQL files in this order:
   1. `01_staging.sql`
   2. `03_dim_neighborhood.sql`
   3. `04_fact_listings.sql`
   4. `02_quality_checks.sql`: every result should match its `Expected` value
   5. `05_analysis.sql`

## Tech

Google BigQuery (SQL), GitHub. Initial exploration in Python (pandas).
