# Results - da-learn-10 Supply chain (DataCo)

Run: `python run_pipeline.py --source full` on DuckDB (local, full file, 180,519 raw order lines → 65,752 orders). Databricks was skipped because the workspace hit its resource quota, so there is no live dashboard; every number below is in `metrics.json` and `tables/`. **Money KPIs = booked orders** (status not CANCELED / SUSPECTED_FRAUD); **delivery KPIs = shipped orders** (delivery status not "Shipping canceled"); **late = actual shipping days > promised days**.

![Dashboard](images/dashboard.png)

## Headline KPIs
| KPI | Value |
|---|---|
| Orders / order lines | 65,752 / 180,519 |
| Customers / products / categories | 20,652 / 118 / 50 |
| Destination countries / markets | 164 / 5 |
| Order dates | 2015-01-01 to 2018-01-31 |
| Booked net sales | $31,644,664.75 |
| Booked profit / margin | $3,806,420.63 / 12.03% |
| Avg booked order value | $503.12 |
| Avg discount (of gross sales) | 10.14% |
| Late / on-time / early (shipped orders) | 57.31% / 18.64% / 24.05% |
| Avg actual vs promised days | 3.502 vs 2.936 |
| Avg delay when late | 1.618 days |
| Loss-making booked lines / orders | 18.69% / 21.13% |
| Losses on loss-making lines | $3,708,393.18 |
| Suspected-fraud / canceled orders | 2.26% / 2.08% |

## Delivery: promise vs reality
| shipping_mode | promised_days | shipped_orders | share_pct | avg_actual_days | late_pct | on_time_pct | early_pct | avg_delay_when_late |
|---|---|---|---|---|---|---|---|---|
| Same Day | 0 | 3,407 | 5.42 | 0.484 | 48.37 | 51.63 | 0.0 | 1.0 |
| First Class | 1 | 9,602 | 15.27 | 2.0 | 100.0 | 0.0 | 0.0 | 1.0 |
| Second Class | 2 | 12,256 | 19.49 | 4.003 | 79.99 | 20.01 | 0.0 | 2.504 |
| Standard Class | 4 | 37,632 | 59.83 | 3.995 | 39.85 | 19.96 | 40.2 | 1.503 |

First Class always takes 2 days against a 1-day promise, so every First Class order is late. Second Class takes 2-6 days (average 4.00) against 2. Standard Class is the only mode that is often early.

![mode](images/late_rate_by_shipping_mode.png)

Late rate by market and mode (`tables/a_late_by_mode_market.csv`) is the same picture in every market, so geography is not the driver:

![market x mode](images/late_rate_by_market_and_mode.png)

Days late (actual minus promised), shipped orders:

| delay_days | shipped_orders | share_pct |
|---|---|---|
| -2 | 7,610 | 12.1 |
| -1 | 7,517 | 11.95 |
| 0 | 11,722 | 18.64 |
| 1 | 21,130 | 33.59 |
| 2 | 10,010 | 15.91 |
| 3 | 2,452 | 3.9 |
| 4 | 2,456 | 3.9 |

![delay](images/delay_distribution.png)

## Markets
| market | orders | booked_net_sales | booked_profit | margin_pct | late_pct | suspected_fraud_pct | avg_order_value |
|---|---|---|---|---|---|---|---|
| Europe | 18,561 | 9,348,369.23 | 1,131,937.91 | 12.11 | 57.42 | 2.3 | 526.28 |
| LATAM | 17,181 | 8,829,847.07 | 1,069,050.79 | 12.11 | 56.9 | 2.32 | 537.95 |
| Pacific Asia | 17,577 | 7,137,290.21 | 826,167.16 | 11.58 | 57.68 | 2.1 | 423.5 |
| USCA | 8,579 | 4,346,978.39 | 539,223.29 | 12.4 | 57.52 | 2.44 | 531.55 |
| Africa | 3,854 | 1,982,179.85 | 240,041.48 | 12.11 | 56.55 | 2.23 | 537.32 |

Top destination countries by booked sales: **United States** $4.19M, **France** $2.48M, **Mexico** $2.27M, **Germany** $1.78M, **Australia** $1.46M (full top 20: `tables/a_country_top.csv`; regions: `tables/a_region_summary.csv`).

## Departments, categories and products
| department_name | booked_lines | net_sales | sales_share_pct | profit | margin_pct | loss_line_pct | discount_pct |
|---|---|---|---|---|---|---|---|
| Fan Shop | 64,033 | 14,730,174.46 | 46.55 | 1,759,600.96 | 11.95 | 18.68 | 10.14 |
| Apparel | 46,884 | 6,858,958.78 | 21.67 | 845,530.37 | 12.33 | 18.71 | 10.13 |
| Golf | 31,768 | 3,962,014.27 | 12.52 | 476,328.82 | 12.02 | 18.95 | 10.12 |
| Footwear | 13,891 | 3,443,986.87 | 10.88 | 388,979.27 | 11.29 | 18.67 | 10.17 |
| Outdoors | 9,267 | 1,078,728.29 | 3.41 | 141,336.69 | 13.1 | 17.86 | 10.18 |
| Technology | 1,396 | 893,686.53 | 2.82 | 111,588.83 | 12.49 | 17.48 | 10.18 |
| Fitness | 2,374 | 342,216.42 | 1.08 | 45,270.16 | 13.23 | 17.57 | 9.98 |
| Discs Shop | 1,943 | 196,910.76 | 0.62 | 24,144.80 | 12.26 | 19.51 | 10.12 |
| Health and Beauty | 346 | 91,249.68 | 0.29 | 9,281.12 | 10.17 | 23.41 | 10.0 |
| Pet Shop | 472 | 35,834.98 | 0.11 | 3,505.18 | 9.78 | 20.55 | 10.05 |
| Book Shop | 391 | 10,904.04 | 0.03 | 854.44 | 7.84 | 19.18 | 10.27 |

![departments](images/sales_by_department.png)

Product concentration: 118 products sold; the top 1 / 5 / 10 hold 18.85% / 60.6% / 89.99% of booked sales.

| rank_by_sales | product_name | category_name | booked_lines | net_sales | sales_share_pct | margin_pct |
|---|---|---|---|---|---|---|
| 1 | Field & Stream Sportsman 16 Gun Fire Safe | Fishing | 16,595 | 5,964,765.44 | 18.85 | 12.26 |
| 2 | Perfect Fitness Perfect Rip Deck | Cleats | 23,478 | 3,805,977.27 | 12.03 | 12.45 |
| 3 | Diamondback Women's Serene Classic Comfort Bi | Camping & Hiking | 13,157 | 3,546,428.27 | 11.21 | 11.56 |
| 4 | Nike Men's Free 5.0+ Running Shoe | Cardio Equipment | 11,646 | 3,151,671.16 | 9.96 | 11.42 |
| 5 | Nike Men's Dri-FIT Victory Golf Polo | Women's Apparel | 20,116 | 2,706,768.50 | 8.55 | 12.35 |
| 6 | Pelican Sunstream 100 Kayak | Water Sports | 14,840 | 2,666,730.68 | 8.43 | 11.55 |
| 7 | O'Brien Men's Neoprene Life Vest | Indoor/Outdoor Games | 18,470 | 2,485,575.58 | 7.85 | 12.17 |
| 8 | Nike Men's CJ Elite 2 TD Football Cleat | Men's Footwear | 21,263 | 2,483,852.70 | 7.85 | 11.95 |
| 9 | Under Armour Girls' Toddler Spine Surge Runni | Shop By Sport | 10,164 | 1,092,050.65 | 3.45 | 11.16 |
| 10 | Dell Laptop | Computers | 425 | 572,527.50 | 1.81 | 12.09 |

![products](images/top_products.png)

Category table (51 department x category rows, ranks by sales and profit): `tables/a_category_summary.csv`.

## Profitability: discounts and delays
| discount_band | booked_lines | avg_discount_rate_pct | net_sales | margin_pct | loss_line_pct |
|---|---|---|---|---|---|
| a 0% | 9,640 | 0.0 | 1,966,128.08 | 12.95 | 18.57 |
| b 1-5% | 38,384 | 2.5 | 7,620,176.45 | 11.71 | 18.68 |
| c 6-10% | 38,418 | 6.75 | 7,314,318.64 | 12.38 | 18.43 |
| d 11-15% | 28,717 | 11.66 | 5,170,240.45 | 11.89 | 18.81 |
| e 16-20% | 38,404 | 16.5 | 6,538,301.33 | 11.87 | 18.85 |
| f 21-25% | 19,202 | 22.49 | 3,035,500.13 | 11.94 | 18.82 |

| delivery_outcome | lines | net_sales | margin_pct | loss_line_pct |
|---|---|---|---|---|
| early | 41,592 | 7,656,338.75 | 12.22 | 18.69 |
| late | 98,977 | 18,082,555.30 | 11.83 | 18.74 |
| on time | 32,196 | 5,905,771.03 | 12.38 | 18.54 |

Neither the discount band nor the delivery outcome moves margin by more than about 1.2 points; roughly 1 line in 5 loses money everywhere.

![discount](images/discount_vs_margin.png)

## Payment type, order status and fraud
| payment_type | order_status | orders | share_of_payment_type_pct | net_sales |
|---|---|---|---|---|
| CASH | CLOSED | 7,249 | 100.0 | 3,617,466.81 |
| DEBIT | COMPLETE | 21,716 | 85.7 | 10,859,271.62 |
| DEBIT | ON_HOLD | 3,624 | 14.3 | 1,780,237.68 |
| PAYMENT | PAYMENT_REVIEW | 704 | 4.67 | 345,576.16 |
| PAYMENT | PENDING_PAYMENT | 14,382 | 95.33 | 7,286,275.56 |
| TRANSFER | CANCELED | 1,367 | 7.56 | 668,244.98 |
| TRANSFER | PENDING | 7,321 | 40.5 | 3,704,456.19 |
| TRANSFER | PROCESSING | 7,901 | 43.71 | 4,051,380.73 |
| TRANSFER | SUSPECTED_FRAUD | 1,488 | 8.23 | 741,492.31 |

Every order status maps to exactly one payment type (asserted). All suspected-fraud orders are bank transfers. Regional fraud rates: `tables/a_fraud_by_region.csv` (highest share of transfers: Canada 11.0%, West of USA 10.41%, Southern Africa 10.31%).

![fraud](images/fraud_by_payment_type.png)

## Trend
| year | orders | booked_net_sales | margin_pct | late_pct | active_customers |
|---|---|---|---|---|---|
| 2,015 | 20,904 | 10,620,464.81 | 11.87 | 57.17 | 10,131 |
| 2,016 | 20,859 | 10,599,126.92 | 11.83 | 57.61 | 10,222 |
| 2,017 | 21,866 | 10,140,401.01 | 12.43 | 57.03 | 15,156 |
| 2,018 | 2,123 | 284,672.01 | 11.37 | 58.66 | 2,123 |

2018 is January only. From Oct 2017 every order has exactly one line (avg lines per order 1.0-1.07 vs about 3.0 before) and only 8-20 products are sold a month; those orders are flagged `is_late_2017_regime`. Monthly detail: `tables/a_monthly_trend.csv`.

![trend](images/monthly_sales_trend.png)

## Customer segments
| customer_segment | orders | customers | booked_net_sales | margin_pct | avg_order_value | late_pct |
|---|---|---|---|---|---|---|
| Consumer | 34,119 | 10,695 | 16,417,549.44 | 12.08 | 503.39 | 57.25 |
| Corporate | 19,856 | 6,239 | 9,621,051.58 | 12.03 | 505.92 | 57.16 |
| Home Office | 11,777 | 3,718 | 5,606,063.73 | 11.88 | 497.61 | 57.74 |

## Data quality
Row counts:

| entity | raw_rows | distinct_keys | clean_rows | grain |
|---|---|---|---|---|
| dim_customer |  | 20,652 | 20,652 | customer_id |
| dim_date |  |  | 1,133 | calendar day (order or ship) |
| dim_geography |  |  | 3,772 | market x region x country x state x city |
| dim_order_status |  |  | 9 | order status |
| dim_product |  | 118 | 118 | product_id |
| dim_shipping_mode |  |  | 4 | shipping mode |
| fact_order |  |  | 65,752 | order |
| fact_order_item |  |  | 180,519 | order line |
| order_lines | 180,519 | 180,519 | 180,519 | order_item_id |
| orders |  | 65,752 | 65,752 | order_id |

Issues found and how they were handled:

| check_name | affected_rows |
|---|---|
| constant or empty columns dropped (product_status = 0, product_description empty) | 2 |
| customer address shifted one column (state held a zip code) - repaired | 3 |
| customer_country 'EE. UU.' standardised to United States | 111,146 |
| department_name with trailing space trimmed | 362 |
| masked / PII columns dropped (email, password = XXXXXXXXX; names, street) | 5 |
| order lines where profit <> net_sales * rounded profit_ratio (> 0.05, ratio is 2 dp) | 64,495 |
| order lines with negative profit (kept) | 33,784 |
| order lines with profit outside Q1/Q3 -/+ 3*IQR (flagged, kept) | 7,964 |
| order_country in Spanish translated to English (data/reference) | 124,846 |
| order_lines: duplicate order_item_id rows dropped | 0 |
| order_region with double / trailing spaces normalised | 17,925 |
| orders CANCELED or SUSPECTED_FRAUD (excluded from money KPIs, kept) | 2,855 |
| orders from Oct 2017 on (1 line per order, few products: flagged regime change) | 8,403 |
| orders with Shipping canceled (excluded from delivery KPIs, kept) | 2,855 |
| redundant duplicate columns dropped (identity asserted below) | 6 |

Missing values:

| column_name | raw_missing_pct | clean_null_pct | treatment |
|---|---|---|---|
| customer_lname | 0.004 |  | customer names, e-mail, password, street dropped (PII / masked) |
| customer_zipcode | 0.002 | 0.0 | recovered from the shifted customer_state value |
| order_zipcode | 86.24 | 86.24 | only US destinations carry one; kept as NULL, not used in KPIs |
| product_description | 100.0 |  | always empty -> column dropped |

Assertions (22 / 22 pass):

| check_name | failed_rows | status |
|---|---|---|
| customer attributes identical on every line of a customer | 0 | PASS |
| every order / shipping timestamp parsed | 0 | PASS |
| every order country mapped to English | 0 | PASS |
| fact_order order_date / ship_date -> dim_date | 0 | PASS |
| fact_order rows = distinct raw order_id | 0 | PASS |
| fact_order.customer_id -> dim_customer | 0 | PASS |
| fact_order.geo_key -> dim_geography | 0 | PASS |
| fact_order_item rows = raw rows (no line lost) | 0 | PASS |
| fact_order_item.order_id -> fact_order | 0 | PASS |
| fact_order_item.order_item_id unique | 0 | PASS |
| fact_order_item.product_id -> dim_product | 0 | PASS |
| gross_sales = unit_price * quantity | 0 | PASS |
| line net_sales reconcile to fact_order (abs diff < 1) | 0 | PASS |
| net_sales = gross_sales - discount_amount | 0 | PASS |
| one payment_type per order status | 0 | PASS |
| one promised_days per shipping mode | 0 | PASS |
| order-level attributes identical on every line of an order | 0 | PASS |
| product attributes identical on every line of a product | 0 | PASS |
| quantity 1-5 and discount_rate 0-0.25 | 0 | PASS |
| redundant columns identical (benefit/profit, sales per customer/total, ids, prices) | 0 | PASS |
| ship_date - order_date = days_real | 0 | PASS |
| source Late_delivery_risk = derived late_flag (shipped lines) | 0 | PASS |

## How the charts were made
`run_pipeline.py` runs `sql/00`-`05` on DuckDB, exports the `a_*` and `dq_*` tables to `tables/`, and `scripts/make_charts.py` draws every chart from those CSVs as plain SVG shapes (rect, line, polyline, text; no embedded images). `scripts/render_png.py` rasterises each SVG to a 2x PNG with headless Chrome. The sample run writes the same files under `sample/`.

## Files
- `metrics.json` - KPIs, analysis table list, data-quality block, engine versions, SQL timings (00_duckdb_compat.sql 0.002s, 01_staging.sql 0.665s, 02_cleaning.sql 0.926s, 03_model.sql 0.237s, 04_analysis.sql 0.112s, 05_quality_checks.sql 0.129s)
- `JSON.shot` - headline snapshot + run config (valid JSON)
- `tables/*.csv` - every `a_*` analysis table and `dq_*` table
- `images/*.svg`, `images/*.png` - 8 charts + `dashboard`
