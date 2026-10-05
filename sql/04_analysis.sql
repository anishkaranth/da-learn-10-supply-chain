-- 04_analysis.sql  Business KPIs (Spark SQL dialect).
-- Money KPIs use BOOKED lines/orders only (order_status not CANCELED / SUSPECTED_FRAUD); net_sales = Order Item Total
-- (after discount); profit = Order Profit Per Order (an order-line value in this file despite the name).
-- Delivery KPIs use SHIPPED orders only (delivery_status <> 'Shipping canceled'); late = real days > promised days.

CREATE OR REPLACE TABLE a_kpi_headline AS
SELECT (SELECT COUNT(*) FROM fact_order_item) AS order_lines_total,
       (SELECT COUNT(*) FROM fact_order) AS orders_total,
       (SELECT COUNT(*) FROM dim_customer) AS customers_total,
       (SELECT COUNT(*) FROM dim_product) AS products_total,
       (SELECT COUNT(DISTINCT category_name) FROM dim_product) AS categories_total,
       (SELECT COUNT(DISTINCT order_country) FROM dim_geography) AS countries_total,
       (SELECT COUNT(DISTINCT market) FROM dim_geography) AS markets_total,
       (SELECT MIN(order_date) FROM fact_order) AS first_order_date,
       (SELECT MAX(order_date) FROM fact_order) AS last_order_date,
       (SELECT ROUND(SUM(net_sales), 2) FROM fact_order WHERE is_booked = 1) AS booked_net_sales,
       (SELECT ROUND(SUM(profit), 2) FROM fact_order WHERE is_booked = 1) AS booked_profit,
       (SELECT ROUND(100.0 * SUM(profit) / SUM(net_sales), 2) FROM fact_order WHERE is_booked = 1) AS profit_margin_pct,
       (SELECT ROUND(AVG(net_sales), 2) FROM fact_order WHERE is_booked = 1) AS avg_order_value,
       (SELECT ROUND(100.0 * SUM(discount_amount) / SUM(gross_sales), 2) FROM fact_order WHERE is_booked = 1) AS avg_discount_pct,
       (SELECT ROUND(100.0 * AVG(late_flag), 2) FROM fact_order WHERE is_shipped = 1) AS late_order_pct,
       (SELECT ROUND(100.0 * AVG(CASE WHEN delivery_outcome = 'on time' THEN 1 ELSE 0 END), 2) FROM fact_order WHERE is_shipped = 1) AS on_time_order_pct,
       (SELECT ROUND(100.0 * AVG(CASE WHEN delivery_outcome = 'early' THEN 1 ELSE 0 END), 2) FROM fact_order WHERE is_shipped = 1) AS early_order_pct,
       (SELECT ROUND(AVG(delay_days), 3) FROM fact_order WHERE is_shipped = 1 AND late_flag = 1) AS avg_delay_days_when_late,
       (SELECT ROUND(AVG(days_real), 3) FROM fact_order WHERE is_shipped = 1) AS avg_actual_days,
       (SELECT ROUND(AVG(days_scheduled), 3) FROM fact_order WHERE is_shipped = 1) AS avg_promised_days,
       (SELECT ROUND(100.0 * AVG(is_loss), 2) FROM fact_order_item WHERE is_booked = 1) AS loss_line_pct,
       (SELECT ROUND(100.0 * AVG(is_loss_order), 2) FROM fact_order WHERE is_booked = 1) AS loss_order_pct,
       (SELECT ROUND(-SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END), 2) FROM fact_order_item WHERE is_booked = 1) AS loss_lines_total_loss,
       (SELECT ROUND(100.0 * AVG(is_suspected_fraud), 2) FROM fact_order) AS suspected_fraud_order_pct,
       (SELECT ROUND(100.0 * AVG(CASE WHEN order_status = 'CANCELED' THEN 1 ELSE 0 END), 2) FROM fact_order) AS canceled_order_pct;

-- Delivery promise vs reality by shipping mode (shipped orders)
CREATE OR REPLACE TABLE a_delivery_by_mode AS
SELECT m.shipping_mode, m.promised_days, COUNT(*) AS shipped_orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_order WHERE is_shipped = 1), 2) AS share_pct,
       ROUND(AVG(o.days_real), 3) AS avg_actual_days,
       ROUND(100.0 * AVG(o.late_flag), 2) AS late_pct,
       ROUND(100.0 * AVG(CASE WHEN o.delivery_outcome = 'on time' THEN 1 ELSE 0 END), 2) AS on_time_pct,
       ROUND(100.0 * AVG(CASE WHEN o.delivery_outcome = 'early' THEN 1 ELSE 0 END), 2) AS early_pct,
       ROUND(AVG(CASE WHEN o.late_flag = 1 THEN o.delay_days END), 3) AS avg_delay_when_late,
       MIN(o.days_real) AS min_actual_days, MAX(o.days_real) AS max_actual_days
FROM fact_order o JOIN dim_shipping_mode m ON m.shipping_mode_key = o.shipping_mode_key
WHERE o.is_shipped = 1
GROUP BY m.shipping_mode, m.promised_days;

-- Late rate by market x shipping mode: is lateness about geography or about the service level?
CREATE OR REPLACE TABLE a_late_by_mode_market AS
SELECT o.market, o.shipping_mode, COUNT(*) AS shipped_orders, ROUND(100.0 * AVG(o.late_flag), 2) AS late_pct
FROM fact_order o WHERE o.is_shipped = 1
GROUP BY o.market, o.shipping_mode;

CREATE OR REPLACE TABLE a_delay_distribution AS
SELECT delay_days, COUNT(*) AS shipped_orders,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_order WHERE is_shipped = 1), 2) AS share_pct
FROM fact_order WHERE is_shipped = 1 GROUP BY delay_days;

CREATE OR REPLACE TABLE a_market_summary AS
SELECT market, COUNT(*) AS orders,
       ROUND(SUM(CASE WHEN is_booked = 1 THEN net_sales ELSE 0 END), 2) AS booked_net_sales,
       ROUND(SUM(CASE WHEN is_booked = 1 THEN profit ELSE 0 END), 2) AS booked_profit,
       ROUND(100.0 * SUM(CASE WHEN is_booked = 1 THEN profit ELSE 0 END) / SUM(CASE WHEN is_booked = 1 THEN net_sales ELSE 0 END), 2) AS margin_pct,
       ROUND(100.0 * AVG(CASE WHEN is_shipped = 1 THEN late_flag END), 2) AS late_pct,
       ROUND(100.0 * AVG(is_suspected_fraud), 2) AS suspected_fraud_pct,
       ROUND(AVG(CASE WHEN is_booked = 1 THEN net_sales END), 2) AS avg_order_value
FROM fact_order GROUP BY market;

CREATE OR REPLACE TABLE a_region_summary AS
SELECT g.market, g.order_region, COUNT(*) AS orders,
       ROUND(SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS booked_net_sales,
       ROUND(100.0 * SUM(CASE WHEN o.is_booked = 1 THEN o.profit ELSE 0 END) / SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS margin_pct,
       ROUND(100.0 * AVG(CASE WHEN o.is_shipped = 1 THEN o.late_flag END), 2) AS late_pct,
       ROUND(100.0 * AVG(o.is_suspected_fraud), 2) AS suspected_fraud_pct
FROM fact_order o JOIN dim_geography g ON g.geo_key = o.geo_key
GROUP BY g.market, g.order_region;

CREATE OR REPLACE TABLE a_country_top AS
SELECT * FROM (
  SELECT g.order_country, MIN(g.market) AS market, COUNT(*) AS orders,
         ROUND(SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS booked_net_sales,
         ROUND(100.0 * SUM(CASE WHEN o.is_booked = 1 THEN o.profit ELSE 0 END) / SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS margin_pct,
         ROUND(100.0 * AVG(CASE WHEN o.is_shipped = 1 THEN o.late_flag END), 2) AS late_pct,
         ROW_NUMBER() OVER (ORDER BY SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END) DESC) AS rank_by_sales
  FROM fact_order o JOIN dim_geography g ON g.geo_key = o.geo_key
  GROUP BY g.order_country
) x WHERE rank_by_sales <= 20;

CREATE OR REPLACE TABLE a_department_summary AS
SELECT p.department_name, COUNT(*) AS booked_lines, SUM(i.quantity) AS units,
       ROUND(SUM(i.net_sales), 2) AS net_sales,
       ROUND(100.0 * SUM(i.net_sales) / (SELECT SUM(net_sales) FROM fact_order_item WHERE is_booked = 1), 2) AS sales_share_pct,
       ROUND(SUM(i.profit), 2) AS profit,
       ROUND(100.0 * SUM(i.profit) / SUM(i.net_sales), 2) AS margin_pct,
       ROUND(100.0 * AVG(i.is_loss), 2) AS loss_line_pct,
       ROUND(100.0 * SUM(i.discount_amount) / SUM(i.gross_sales), 2) AS discount_pct
FROM fact_order_item i JOIN dim_product p ON p.product_id = i.product_id
WHERE i.is_booked = 1
GROUP BY p.department_name;

CREATE OR REPLACE TABLE a_category_summary AS
SELECT p.department_name, p.category_name, COUNT(*) AS booked_lines,
       ROUND(SUM(i.net_sales), 2) AS net_sales,
       ROUND(SUM(i.profit), 2) AS profit,
       ROUND(100.0 * SUM(i.profit) / SUM(i.net_sales), 2) AS margin_pct,
       ROUND(100.0 * AVG(i.is_loss), 2) AS loss_line_pct,
       ROW_NUMBER() OVER (ORDER BY SUM(i.net_sales) DESC) AS rank_by_sales,
       ROW_NUMBER() OVER (ORDER BY SUM(i.profit) DESC) AS rank_by_profit
FROM fact_order_item i JOIN dim_product p ON p.product_id = i.product_id
WHERE i.is_booked = 1
GROUP BY p.department_name, p.category_name;

CREATE OR REPLACE TABLE a_top_products AS
SELECT * FROM (
  SELECT p.product_name, p.category_name, p.list_price, COUNT(*) AS booked_lines, SUM(i.quantity) AS units,
         ROUND(SUM(i.net_sales), 2) AS net_sales,
         ROUND(100.0 * SUM(i.net_sales) / (SELECT SUM(net_sales) FROM fact_order_item WHERE is_booked = 1), 2) AS sales_share_pct,
         ROUND(SUM(i.profit), 2) AS profit,
         ROUND(100.0 * SUM(i.profit) / SUM(i.net_sales), 2) AS margin_pct,
         ROW_NUMBER() OVER (ORDER BY SUM(i.net_sales) DESC) AS rank_by_sales
  FROM fact_order_item i JOIN dim_product p ON p.product_id = i.product_id
  WHERE i.is_booked = 1
  GROUP BY p.product_name, p.category_name, p.list_price
) x WHERE rank_by_sales <= 15;

CREATE OR REPLACE TABLE a_product_concentration AS
WITH r AS (
  SELECT product_id, SUM(net_sales) AS s, ROW_NUMBER() OVER (ORDER BY SUM(net_sales) DESC) AS rk
  FROM fact_order_item WHERE is_booked = 1 GROUP BY product_id
)
SELECT (SELECT COUNT(*) FROM r) AS products_sold,
       ROUND(100.0 * SUM(CASE WHEN rk <= 1 THEN s ELSE 0 END) / SUM(s), 2) AS top1_share_pct,
       ROUND(100.0 * SUM(CASE WHEN rk <= 5 THEN s ELSE 0 END) / SUM(s), 2) AS top5_share_pct,
       ROUND(100.0 * SUM(CASE WHEN rk <= 10 THEN s ELSE 0 END) / SUM(s), 2) AS top10_share_pct
FROM r;

CREATE OR REPLACE TABLE a_discount_vs_margin AS
SELECT discount_band, COUNT(*) AS booked_lines, ROUND(100.0 * AVG(discount_rate), 2) AS avg_discount_rate_pct,
       ROUND(SUM(net_sales), 2) AS net_sales,
       ROUND(100.0 * SUM(profit) / SUM(net_sales), 2) AS margin_pct,
       ROUND(100.0 * AVG(is_loss), 2) AS loss_line_pct
FROM fact_order_item WHERE is_booked = 1 GROUP BY discount_band;

-- Does a late delivery coincide with lower profit? (booked + shipped lines)
CREATE OR REPLACE TABLE a_late_vs_profit AS
SELECT delivery_outcome, COUNT(*) AS lines,
       ROUND(SUM(net_sales), 2) AS net_sales,
       ROUND(100.0 * SUM(profit) / SUM(net_sales), 2) AS margin_pct,
       ROUND(100.0 * AVG(is_loss), 2) AS loss_line_pct
FROM fact_order_item WHERE is_booked = 1 AND delivery_outcome <> 'canceled' GROUP BY delivery_outcome;

CREATE OR REPLACE TABLE a_payment_status AS
SELECT payment_type, order_status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY payment_type), 2) AS share_of_payment_type_pct,
       ROUND(SUM(net_sales), 2) AS net_sales
FROM fact_order GROUP BY payment_type, order_status;

CREATE OR REPLACE TABLE a_fraud_by_region AS
SELECT g.market, g.order_region, COUNT(*) AS orders,
       SUM(o.is_suspected_fraud) AS suspected_fraud_orders,
       ROUND(100.0 * AVG(o.is_suspected_fraud), 2) AS suspected_fraud_pct,
       ROUND(100.0 * SUM(o.is_suspected_fraud) / SUM(CASE WHEN o.payment_type = 'TRANSFER' THEN 1 ELSE 0 END), 2) AS fraud_pct_of_transfers,
       ROUND(SUM(CASE WHEN o.is_suspected_fraud = 1 THEN o.net_sales ELSE 0 END), 2) AS suspected_fraud_sales
FROM fact_order o JOIN dim_geography g ON g.geo_key = o.geo_key
GROUP BY g.market, g.order_region;

CREATE OR REPLACE TABLE a_monthly_trend AS
SELECT d.year_month, MIN(d.is_late_2017_regime) AS is_late_2017_regime, COUNT(*) AS orders,
       SUM(o.order_lines) AS order_lines,
       ROUND(SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS booked_net_sales,
       ROUND(SUM(CASE WHEN o.is_booked = 1 THEN o.profit ELSE 0 END), 2) AS booked_profit,
       ROUND(100.0 * SUM(CASE WHEN o.is_booked = 1 THEN o.profit ELSE 0 END) / SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS margin_pct,
       ROUND(100.0 * AVG(CASE WHEN o.is_shipped = 1 THEN o.late_flag END), 2) AS late_pct,
       ROUND(AVG(o.order_lines), 3) AS avg_lines_per_order
FROM fact_order o JOIN dim_date d ON d.date_key = o.order_date
GROUP BY d.year_month;

CREATE OR REPLACE TABLE a_yearly_summary AS
SELECT d.year, COUNT(*) AS orders,
       ROUND(SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS booked_net_sales,
       ROUND(100.0 * SUM(CASE WHEN o.is_booked = 1 THEN o.profit ELSE 0 END) / SUM(CASE WHEN o.is_booked = 1 THEN o.net_sales ELSE 0 END), 2) AS margin_pct,
       ROUND(100.0 * AVG(CASE WHEN o.is_shipped = 1 THEN o.late_flag END), 2) AS late_pct,
       COUNT(DISTINCT o.customer_id) AS active_customers
FROM fact_order o JOIN dim_date d ON d.date_key = o.order_date
GROUP BY d.year;

CREATE OR REPLACE TABLE a_segment_summary AS
SELECT customer_segment, COUNT(*) AS orders, COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(CASE WHEN is_booked = 1 THEN net_sales ELSE 0 END), 2) AS booked_net_sales,
       ROUND(100.0 * SUM(CASE WHEN is_booked = 1 THEN profit ELSE 0 END) / SUM(CASE WHEN is_booked = 1 THEN net_sales ELSE 0 END), 2) AS margin_pct,
       ROUND(AVG(CASE WHEN is_booked = 1 THEN net_sales END), 2) AS avg_order_value,
       ROUND(100.0 * AVG(CASE WHEN is_shipped = 1 THEN late_flag END), 2) AS late_pct
FROM fact_order GROUP BY customer_segment;
