-- 05_quality_checks.sql  Data-quality evidence (Spark SQL dialect)

CREATE OR REPLACE TABLE dq_row_counts AS
SELECT 'order_lines' AS entity, (SELECT COUNT(*) FROM stg_dataco) AS raw_rows,
       (SELECT COUNT(DISTINCT order_item_id) FROM stg_dataco) AS distinct_keys,
       (SELECT COUNT(*) FROM cln_order_items) AS clean_rows, 'order_item_id' AS grain
UNION ALL SELECT 'orders', NULL, (SELECT COUNT(DISTINCT order_id) FROM stg_dataco), (SELECT COUNT(*) FROM cln_orders), 'order_id'
UNION ALL SELECT 'fact_order_item', NULL, NULL, (SELECT COUNT(*) FROM fact_order_item), 'order line'
UNION ALL SELECT 'fact_order', NULL, NULL, (SELECT COUNT(*) FROM fact_order), 'order'
UNION ALL SELECT 'dim_customer', NULL, (SELECT COUNT(DISTINCT customer_id) FROM stg_dataco), (SELECT COUNT(*) FROM dim_customer), 'customer_id'
UNION ALL SELECT 'dim_product', NULL, (SELECT COUNT(DISTINCT product_card_id) FROM stg_dataco), (SELECT COUNT(*) FROM dim_product), 'product_id'
UNION ALL SELECT 'dim_geography', NULL, NULL, (SELECT COUNT(*) FROM dim_geography), 'market x region x country x state x city'
UNION ALL SELECT 'dim_shipping_mode', NULL, NULL, (SELECT COUNT(*) FROM dim_shipping_mode), 'shipping mode'
UNION ALL SELECT 'dim_order_status', NULL, NULL, (SELECT COUNT(*) FROM dim_order_status), 'order status'
UNION ALL SELECT 'dim_date', NULL, NULL, (SELECT COUNT(*) FROM dim_date), 'calendar day (order or ship)';

CREATE OR REPLACE TABLE dq_null_rates AS
SELECT 'stg_dataco' AS entity, 'product_description' AS column_name,
  (SELECT ROUND(100.0 * SUM(CASE WHEN product_description IS NULL OR trim(product_description) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_dataco) AS raw_missing_pct,
  CAST(NULL AS DOUBLE) AS clean_null_pct, 'always empty -> column dropped' AS treatment
UNION ALL SELECT 'stg_dataco', 'order_zipcode',
  (SELECT ROUND(100.0 * SUM(CASE WHEN order_zipcode IS NULL OR trim(order_zipcode) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_dataco),
  (SELECT ROUND(100.0 * SUM(CASE WHEN order_zipcode IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_order_items),
  'only US destinations carry one; kept as NULL, not used in KPIs'
UNION ALL SELECT 'stg_dataco', 'customer_zipcode',
  (SELECT ROUND(100.0 * SUM(CASE WHEN customer_zipcode IS NULL OR trim(customer_zipcode) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_dataco),
  (SELECT ROUND(100.0 * SUM(CASE WHEN customer_zipcode IS NULL THEN 1 ELSE 0 END) / COUNT(*), 3) FROM cln_order_items),
  'recovered from the shifted customer_state value'
UNION ALL SELECT 'stg_dataco', 'customer_lname',
  (SELECT ROUND(100.0 * SUM(CASE WHEN customer_lname IS NULL OR trim(customer_lname) = '' THEN 1 ELSE 0 END) / COUNT(*), 3) FROM stg_dataco),
  CAST(NULL AS DOUBLE), 'customer names, e-mail, password, street dropped (PII / masked)';

CREATE OR REPLACE TABLE dq_issues AS
SELECT 'order_lines: duplicate order_item_id rows dropped' AS check_name,
       (SELECT COUNT(*) FROM stg_dataco) - (SELECT COUNT(*) FROM cln_order_items) AS affected_rows
UNION ALL SELECT 'customer address shifted one column (state held a zip code) - repaired', (SELECT SUM(dq_address_shift_fixed) FROM cln_order_items)
UNION ALL SELECT 'customer_country ''EE. UU.'' standardised to United States', (SELECT COUNT(*) FROM stg_dataco WHERE trim(customer_country) = 'EE. UU.')
UNION ALL SELECT 'order_country in Spanish translated to English (data/reference)', (SELECT COUNT(*) FROM cln_order_items WHERE order_country <> order_country_es)
UNION ALL SELECT 'order_region with double / trailing spaces normalised', (SELECT COUNT(*) FROM stg_dataco WHERE order_region <> trim(replace(order_region, '  ', ' ')))
UNION ALL SELECT 'department_name with trailing space trimmed', (SELECT COUNT(*) FROM stg_dataco WHERE department_name <> trim(department_name))
UNION ALL SELECT 'masked / PII columns dropped (email, password = XXXXXXXXX; names, street)', 5
UNION ALL SELECT 'constant or empty columns dropped (product_status = 0, product_description empty)', 2
UNION ALL SELECT 'redundant duplicate columns dropped (identity asserted below)', 6
UNION ALL SELECT 'orders CANCELED or SUSPECTED_FRAUD (excluded from money KPIs, kept)', (SELECT SUM(1 - is_booked) FROM fact_order)
UNION ALL SELECT 'orders with Shipping canceled (excluded from delivery KPIs, kept)', (SELECT SUM(1 - is_shipped) FROM fact_order)
UNION ALL SELECT 'order lines with negative profit (kept)', (SELECT SUM(is_loss) FROM fact_order_item)
UNION ALL SELECT 'order lines with profit outside Q1/Q3 -/+ 3*IQR (flagged, kept)', (SELECT SUM(is_profit_outlier) FROM fact_order_item)
UNION ALL SELECT 'orders from Oct 2017 on (1 line per order, few products: flagged regime change)', (SELECT SUM(is_late_2017_regime) FROM fact_order)
UNION ALL SELECT 'order lines where profit <> net_sales * rounded profit_ratio (> 0.05, ratio is 2 dp)', (SELECT COUNT(*) FROM cln_order_items WHERE abs(profit - net_sales * profit_ratio) > 0.05);

CREATE OR REPLACE TABLE dq_assertions AS
WITH c AS (
  SELECT 'fact_order_item.order_item_id unique' AS check_name, (SELECT COUNT(*) - COUNT(DISTINCT order_item_id) FROM fact_order_item) AS failed_rows
  UNION ALL SELECT 'fact_order_item rows = raw rows (no line lost)', (SELECT ABS((SELECT COUNT(*) FROM fact_order_item) - (SELECT COUNT(*) FROM stg_dataco)))
  UNION ALL SELECT 'fact_order rows = distinct raw order_id', (SELECT ABS((SELECT COUNT(*) FROM fact_order) - (SELECT COUNT(DISTINCT order_id) FROM stg_dataco)))
  UNION ALL SELECT 'every order / shipping timestamp parsed', (SELECT COUNT(*) FROM cln_order_items WHERE order_ts IS NULL OR ship_ts IS NULL)
  UNION ALL SELECT 'ship_date - order_date = days_real', (SELECT COUNT(*) FROM fact_order WHERE datediff(ship_date, order_date) <> days_real)
  UNION ALL SELECT 'source Late_delivery_risk = derived late_flag (shipped lines)',
         (SELECT COUNT(*) FROM cln_order_items WHERE is_shipped = 1 AND late_delivery_risk <> late_flag)
  UNION ALL SELECT 'redundant columns identical (benefit/profit, sales per customer/total, ids, prices)',
         (SELECT COUNT(*) FROM stg_dataco WHERE benefit_per_order <> order_profit_per_order OR sales_per_customer <> order_item_total
            OR order_customer_id <> customer_id OR product_card_id <> order_item_cardprod_id OR category_id <> product_category_id
            OR product_price <> order_item_product_price)
  UNION ALL SELECT 'order-level attributes identical on every line of an order',
         (SELECT COUNT(*) FROM (SELECT order_id FROM cln_order_items GROUP BY order_id
            HAVING COUNT(DISTINCT order_ts) > 1 OR COUNT(DISTINCT customer_id) > 1 OR COUNT(DISTINCT shipping_mode) > 1
                OR COUNT(DISTINCT order_status) > 1 OR COUNT(DISTINCT order_city) > 1 OR COUNT(DISTINCT days_real) > 1) x)
  UNION ALL SELECT 'customer attributes identical on every line of a customer',
         (SELECT COUNT(*) FROM (SELECT customer_id FROM cln_order_items GROUP BY customer_id
            HAVING COUNT(DISTINCT customer_segment) > 1 OR COUNT(DISTINCT customer_state) > 1) x)
  UNION ALL SELECT 'product attributes identical on every line of a product',
         (SELECT COUNT(*) FROM (SELECT product_id FROM cln_order_items GROUP BY product_id
            HAVING COUNT(DISTINCT product_name) > 1 OR COUNT(DISTINCT category_id) > 1 OR COUNT(DISTINCT unit_price) > 1) x)
  UNION ALL SELECT 'one promised_days per shipping mode', (SELECT COUNT(*) FROM dim_shipping_mode WHERE promised_days_variants <> 1)
  UNION ALL SELECT 'one payment_type per order status', (SELECT COUNT(*) FROM dim_order_status WHERE payment_type_variants <> 1)
  UNION ALL SELECT 'every order country mapped to English', (SELECT SUM(dq_country_unmapped) FROM cln_order_items)
  UNION ALL SELECT 'gross_sales = unit_price * quantity', (SELECT SUM(dq_sales_mismatch) FROM cln_order_items)
  UNION ALL SELECT 'net_sales = gross_sales - discount_amount', (SELECT SUM(dq_total_mismatch) FROM cln_order_items)
  UNION ALL SELECT 'quantity 1-5 and discount_rate 0-0.25',
         (SELECT COUNT(*) FROM fact_order_item WHERE quantity NOT BETWEEN 1 AND 5 OR discount_rate NOT BETWEEN 0 AND 0.25)
  UNION ALL SELECT 'line net_sales reconcile to fact_order (abs diff < 1)',
         (SELECT CASE WHEN abs((SELECT SUM(net_sales) FROM fact_order_item) - (SELECT SUM(net_sales) FROM fact_order)) < 1 THEN 0 ELSE 1 END)
  UNION ALL SELECT 'fact_order_item.product_id -> dim_product', (SELECT COUNT(*) FROM fact_order_item WHERE product_id NOT IN (SELECT product_id FROM dim_product))
  UNION ALL SELECT 'fact_order.customer_id -> dim_customer', (SELECT COUNT(*) FROM fact_order WHERE customer_id NOT IN (SELECT customer_id FROM dim_customer))
  UNION ALL SELECT 'fact_order.geo_key -> dim_geography', (SELECT COUNT(*) FROM fact_order WHERE geo_key NOT IN (SELECT geo_key FROM dim_geography))
  UNION ALL SELECT 'fact_order order_date / ship_date -> dim_date',
         (SELECT COUNT(*) FROM fact_order WHERE order_date NOT IN (SELECT date_key FROM dim_date) OR ship_date NOT IN (SELECT date_key FROM dim_date))
  UNION ALL SELECT 'fact_order_item.order_id -> fact_order', (SELECT COUNT(*) FROM fact_order_item WHERE order_id NOT IN (SELECT order_id FROM fact_order))
)
SELECT check_name, failed_rows, CASE WHEN failed_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS status FROM c;
