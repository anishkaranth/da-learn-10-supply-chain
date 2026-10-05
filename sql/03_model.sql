-- 03_model.sql  Star schema (Spark SQL dialect)
-- Facts: fact_order_item (grain = order line, 180,519) and fact_order (grain = order).
-- Dims : dim_date, dim_customer, dim_product, dim_geography, dim_shipping_mode, dim_order_status.

CREATE OR REPLACE TABLE dim_shipping_mode AS
SELECT DENSE_RANK() OVER (ORDER BY MIN(days_scheduled), shipping_mode) AS shipping_mode_key,
       shipping_mode,
       MIN(days_scheduled) AS promised_days,
       COUNT(DISTINCT days_scheduled) AS promised_days_variants
FROM cln_orders GROUP BY shipping_mode;

CREATE OR REPLACE TABLE dim_order_status AS
SELECT DENSE_RANK() OVER (ORDER BY order_status) AS status_key,
       order_status, MIN(payment_type) AS payment_type, COUNT(DISTINCT payment_type) AS payment_type_variants,
       MIN(is_booked) AS is_booked
FROM cln_orders GROUP BY order_status;

CREATE OR REPLACE TABLE dim_geography AS
SELECT DENSE_RANK() OVER (ORDER BY market, order_region, order_country, order_state, order_city) AS geo_key,
       market, order_region, order_country, order_state, order_city, COUNT(*) AS orders
FROM cln_orders GROUP BY market, order_region, order_country, order_state, order_city;

CREATE OR REPLACE TABLE dim_customer AS
SELECT customer_id,
       MIN(customer_segment) AS customer_segment,
       MIN(customer_city) AS customer_city,
       MIN(customer_state) AS customer_state,
       MIN(customer_zipcode) AS customer_zipcode,
       MIN(customer_country) AS customer_country,
       COUNT(DISTINCT order_id) AS orders,
       MIN(order_date) AS first_order_date,
       MAX(order_date) AS last_order_date
FROM cln_order_items GROUP BY customer_id;

CREATE OR REPLACE TABLE dim_product AS
SELECT product_id,
       MIN(product_name) AS product_name,
       MIN(category_id) AS category_id,
       MIN(category_name) AS category_name,
       MIN(department_id) AS department_id,
       MIN(department_name) AS department_name,
       MIN(unit_price) AS list_price,
       MIN(product_image_url) AS product_image_url,
       COUNT(*) AS order_lines
FROM cln_order_items GROUP BY product_id;

CREATE OR REPLACE TABLE dim_date AS
SELECT d AS date_key, year(d) AS year, quarter(d) AS quarter, month(d) AS month,
       concat(CAST(year(d) AS STRING), '-', lpad(CAST(month(d) AS STRING), 2, '0')) AS year_month,
       CASE WHEN d >= DATE '2017-10-01' THEN 1 ELSE 0 END AS is_late_2017_regime
FROM (SELECT order_date AS d FROM cln_orders UNION SELECT ship_date FROM cln_orders) x;

CREATE OR REPLACE TABLE fact_order AS
SELECT o.order_id, o.order_date, o.ship_date, o.customer_id, g.geo_key, m.shipping_mode_key, s.status_key,
       o.payment_type, o.order_status, o.delivery_status, o.delivery_outcome, o.shipping_mode, o.market,
       o.customer_segment, o.days_real, o.days_scheduled, o.delay_days, o.late_flag,
       o.is_booked, o.is_suspected_fraud, o.is_shipped, o.is_loss_order, o.is_late_2017_regime,
       o.order_lines, o.units, o.gross_sales, o.discount_amount, o.net_sales, o.profit
FROM cln_orders o
JOIN dim_geography g ON g.market = o.market AND g.order_region = o.order_region AND g.order_country = o.order_country
                    AND g.order_state = o.order_state AND g.order_city = o.order_city
JOIN dim_shipping_mode m ON m.shipping_mode = o.shipping_mode
JOIN dim_order_status s ON s.order_status = o.order_status;

CREATE OR REPLACE TABLE fact_order_item AS
SELECT i.order_item_id, i.order_id, i.order_date, i.ship_date, i.customer_id, i.product_id,
       o.geo_key, o.shipping_mode_key, o.status_key,
       i.quantity, i.unit_price, i.gross_sales, i.discount_rate, i.discount_band, i.discount_amount, i.net_sales,
       i.profit, i.profit_ratio, i.is_loss, i.is_profit_outlier,
       i.days_real, i.days_scheduled, i.delay_days, i.late_flag, i.delivery_outcome, i.is_booked, i.is_suspected_fraud,
       i.is_late_2017_regime
FROM cln_order_items i
JOIN fact_order o ON o.order_id = i.order_id;
