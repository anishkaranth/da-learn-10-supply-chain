# Dashboard spec - "da-learn-10 Supply chain"

One page, 16:9. Slicers: market (dim_geography), shipping mode (dim_shipping_mode), customer segment, year (dim_date), department (dim_product). Optional second page for fraud and data-quality.

| # | Visual | Fields | Expected (full data, no filters) |
|---|---|---|---|
| 1 | KPI cards | Orders, Booked Net Sales, Profit Margin %, Late Rate %, Loss Line %, Suspected Fraud % | 65,752 / $31.64M / 12.03% / 57.31% / 18.69% / 2.26% |
| 2 | Column: late rate by shipping mode | dim_shipping_mode[shipping_mode] sorted by promised_days, [Late Rate %], tooltip [Avg Actual Days], [Avg Promised Days] | Same Day 48.37%, First Class 100%, Second Class 79.99%, Standard Class 39.85% |
| 3 | Clustered column: late rate by market × mode | dim_geography[market], legend dim_shipping_mode[shipping_mode], [Late Rate %] | every market ≈ 100 / 80 / 48 / 40 for First / Second / Same Day / Standard |
| 4 | Bar: booked net sales by department | dim_product[department_name], [Line Net Sales], tooltip [Line Margin %] | Fan Shop $14.73M, Apparel $6.86M, Golf $3.96M |
| 5 | Line: booked net sales by month | dim_date[year_month], [Booked Net Sales] | flat ~$0.89M a month to Sep 2017, then falls to $0.28M (Jan 2018) |
| 6 | Clustered column: discount band vs margin | fact_order_item[discount_band], [Line Margin %], [Loss Line %] | margin 11.7–12.95%, loss lines 18.4–18.9% in every band |
| 7 | Bar: top 10 products | dim_product[product_name], [Line Net Sales], Top N 10, tooltip [Sales Share %] | Field & Stream gun safe $5.96M (18.85%) |
| 8 | Column: suspected fraud by payment type | dim_order_status[payment_type], [Suspected Fraud %] | TRANSFER 8.23%, others 0% |

Reference render of the same visuals (from DuckDB): `results/images/dashboard.png`.
