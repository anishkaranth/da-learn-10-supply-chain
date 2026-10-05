-- 02_cleaning.sql  Cleaning (Spark SQL dialect; runs unchanged on DuckDB after sql/00)
-- Steps: trim + collapse spaces, cast types, parse M/d/yyyy H:mm timestamps, dedupe order items, repair the 3
--        column-shifted customer addresses, translate Spanish country names, drop PII / constant / redundant columns
--        (redundancy asserted in sql/05), derive delivery + profitability fields, outlier and period flags.

-- 1) Typed, standardised order-item rows (grain: order_item_id). Duplicates on order_item_id would be dropped.
CREATE OR REPLACE TABLE cln_order_items_base AS
SELECT CAST(order_item_id AS BIGINT) AS order_item_id,
       CAST(order_id AS BIGINT) AS order_id,
       CAST(customer_id AS BIGINT) AS customer_id,
       CAST(product_card_id AS BIGINT) AS product_id,
       CAST(category_id AS INT) AS category_id,
       CAST(department_id AS INT) AS department_id,
       try_to_timestamp(trim(order_date_raw), 'M/d/yyyy H:mm') AS order_ts,
       try_to_timestamp(trim(shipping_date_raw), 'M/d/yyyy H:mm') AS ship_ts,
       upper(trim(payment_type)) AS payment_type,
       upper(trim(order_status)) AS order_status,
       trim(delivery_status) AS delivery_status,
       trim(shipping_mode) AS shipping_mode,
       CAST(days_shipping_real AS INT) AS days_real,
       CAST(days_shipping_scheduled AS INT) AS days_scheduled,
       CAST(late_delivery_risk AS INT) AS late_delivery_risk,
       trim(market) AS market,
       trim(replace(order_region, '  ', ' ')) AS order_region,
       trim(order_country) AS order_country_es,
       trim(order_state) AS order_state,
       trim(order_city) AS order_city,
       CASE WHEN trim(order_zipcode) = '' THEN NULL ELSE trim(order_zipcode) END AS order_zipcode,
       trim(customer_segment) AS customer_segment,
       -- 3 rows have the address shifted one column left (state holds a zip code, city holds the state)
       CASE WHEN regexp_like(trim(customer_state), '^[0-9]+$') THEN NULL ELSE trim(customer_city) END AS customer_city,
       CASE WHEN regexp_like(trim(customer_state), '^[0-9]+$') THEN trim(customer_city) ELSE trim(customer_state) END AS customer_state,
       CASE WHEN regexp_like(trim(customer_state), '^[0-9]+$') THEN trim(customer_state)
            WHEN trim(customer_zipcode) = '' THEN NULL ELSE trim(customer_zipcode) END AS customer_zipcode,
       CASE WHEN regexp_like(trim(customer_state), '^[0-9]+$') THEN 1 ELSE 0 END AS dq_address_shift_fixed,
       CASE trim(customer_country) WHEN 'EE. UU.' THEN 'United States' ELSE trim(customer_country) END AS customer_country,
       CAST(store_latitude AS DOUBLE) AS store_latitude,
       CAST(store_longitude AS DOUBLE) AS store_longitude,
       trim(product_name) AS product_name,
       trim(category_name) AS category_name,
       trim(department_name) AS department_name,
       trim(product_image) AS product_image_url,
       CAST(order_item_quantity AS INT) AS quantity,
       CAST(order_item_product_price AS DOUBLE) AS unit_price,
       CAST(sales AS DOUBLE) AS gross_sales,
       CAST(order_item_discount AS DOUBLE) AS discount_amount,
       CAST(order_item_discount_rate AS DOUBLE) AS discount_rate,
       CAST(order_item_total AS DOUBLE) AS net_sales,
       CAST(order_profit_per_order AS DOUBLE) AS profit,
       CAST(order_item_profit_ratio AS DOUBLE) AS profit_ratio
FROM stg_dataco
WHERE order_item_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(order_item_id AS BIGINT) ORDER BY order_date_raw) = 1;

-- 2) Derived fields + flags (still order-item grain)
CREATE OR REPLACE TABLE cln_order_items AS
WITH q AS (
  SELECT percentile_approx(profit, 0.25) AS q1, percentile_approx(profit, 0.75) AS q3 FROM cln_order_items_base
)
SELECT b.*,
       coalesce(r.country_en, b.order_country_es) AS order_country,
       CASE WHEN r.country_en IS NULL THEN 1 ELSE 0 END AS dq_country_unmapped,
       CAST(b.order_ts AS DATE) AS order_date,
       CAST(b.ship_ts AS DATE) AS ship_date,
       b.days_real - b.days_scheduled AS delay_days,
       CASE WHEN b.order_status IN ('CANCELED', 'SUSPECTED_FRAUD') THEN 0 ELSE 1 END AS is_booked,
       CASE WHEN b.order_status = 'SUSPECTED_FRAUD' THEN 1 ELSE 0 END AS is_suspected_fraud,
       CASE WHEN b.delivery_status = 'Shipping canceled' THEN 0 ELSE 1 END AS is_shipped,
       CASE WHEN b.delivery_status = 'Shipping canceled' THEN NULL
            WHEN b.days_real > b.days_scheduled THEN 1 ELSE 0 END AS late_flag,
       CASE WHEN b.delivery_status = 'Shipping canceled' THEN 'canceled'
            WHEN b.days_real > b.days_scheduled THEN 'late'
            WHEN b.days_real < b.days_scheduled THEN 'early' ELSE 'on time' END AS delivery_outcome,
       CASE WHEN b.profit < 0 THEN 1 ELSE 0 END AS is_loss,
       CASE WHEN b.discount_rate = 0 THEN 'a 0%' WHEN b.discount_rate <= 0.05 THEN 'b 1-5%'
            WHEN b.discount_rate <= 0.10 THEN 'c 6-10%' WHEN b.discount_rate <= 0.15 THEN 'd 11-15%'
            WHEN b.discount_rate <= 0.20 THEN 'e 16-20%' ELSE 'f 21-25%' END AS discount_band,
       CASE WHEN b.profit < q.q1 - 3 * (q.q3 - q.q1) OR b.profit > q.q3 + 3 * (q.q3 - q.q1) THEN 1 ELSE 0 END AS is_profit_outlier,
       -- from Oct 2017 the file changes shape (1 item per order, 8-20 products a month): flagged, kept
       CASE WHEN b.order_ts >= TIMESTAMP '2017-10-01 00:00:00' THEN 1 ELSE 0 END AS is_late_2017_regime,
       CASE WHEN abs(b.gross_sales - b.unit_price * b.quantity) > 0.02 THEN 1 ELSE 0 END AS dq_sales_mismatch,
       CASE WHEN abs(b.net_sales - (b.gross_sales - b.discount_amount)) > 0.02 THEN 1 ELSE 0 END AS dq_total_mismatch
FROM cln_order_items_base b
LEFT JOIN ref_country r ON r.country_es = b.order_country_es
CROSS JOIN q;

-- 3) One row per order (order-level attributes are identical on every item - asserted in sql/05)
CREATE OR REPLACE TABLE cln_orders AS
SELECT order_id,
       MIN(customer_id) AS customer_id,
       MIN(order_ts) AS order_ts,
       MIN(order_date) AS order_date,
       MIN(ship_ts) AS ship_ts,
       MIN(ship_date) AS ship_date,
       MIN(payment_type) AS payment_type,
       MIN(order_status) AS order_status,
       MIN(delivery_status) AS delivery_status,
       MIN(delivery_outcome) AS delivery_outcome,
       MIN(shipping_mode) AS shipping_mode,
       MIN(days_real) AS days_real,
       MIN(days_scheduled) AS days_scheduled,
       MIN(delay_days) AS delay_days,
       MIN(late_flag) AS late_flag,
       MIN(is_booked) AS is_booked,
       MIN(is_suspected_fraud) AS is_suspected_fraud,
       MIN(is_shipped) AS is_shipped,
       MIN(market) AS market,
       MIN(order_region) AS order_region,
       MIN(order_country) AS order_country,
       MIN(order_state) AS order_state,
       MIN(order_city) AS order_city,
       MIN(customer_segment) AS customer_segment,
       MIN(is_late_2017_regime) AS is_late_2017_regime,
       COUNT(*) AS order_lines,
       SUM(quantity) AS units,
       ROUND(SUM(gross_sales), 2) AS gross_sales,
       ROUND(SUM(discount_amount), 2) AS discount_amount,
       ROUND(SUM(net_sales), 2) AS net_sales,
       ROUND(SUM(profit), 2) AS profit,
       CASE WHEN SUM(profit) < 0 THEN 1 ELSE 0 END AS is_loss_order
FROM cln_order_items
GROUP BY order_id;
