-- 01_staging.sql
-- Land the raw CSV as an all-STRING staging table with snake_case column names (no type inference).
-- {{RAW_DIR}} / {{REF_DIR}} are substituted by run_pipeline.py.
-- DuckDB : read_csv(path, header = true, all_varchar = true)
-- Spark  : read_files('<path>/DataCoSupplyChainDataset.csv', format => 'csv', header => true, inferColumnTypes => false)
--          and use `back-ticks` instead of "double quotes" for the source column names below.
-- DataCoSupplyChainDataset.csv : one row per ORDER ITEM - 180,519 rows x 53 columns. The Mendeley original is
-- Windows-1252 encoded; scripts/download_full_data.py verifies its SHA-256 and writes a UTF-8 copy.
CREATE OR REPLACE TABLE stg_dataco AS
SELECT "Type"                          AS payment_type,
       "Days for shipping (real)"      AS days_shipping_real,
       "Days for shipment (scheduled)" AS days_shipping_scheduled,
       "Benefit per order"             AS benefit_per_order,
       "Sales per customer"            AS sales_per_customer,
       "Delivery Status"               AS delivery_status,
       "Late_delivery_risk"            AS late_delivery_risk,
       "Category Id"                   AS category_id,
       "Category Name"                 AS category_name,
       "Customer City"                 AS customer_city,
       "Customer Country"              AS customer_country,
       "Customer Email"                AS customer_email,
       "Customer Fname"                AS customer_fname,
       "Customer Id"                   AS customer_id,
       "Customer Lname"                AS customer_lname,
       "Customer Password"             AS customer_password,
       "Customer Segment"              AS customer_segment,
       "Customer State"                AS customer_state,
       "Customer Street"               AS customer_street,
       "Customer Zipcode"              AS customer_zipcode,
       "Department Id"                 AS department_id,
       "Department Name"               AS department_name,
       "Latitude"                      AS store_latitude,
       "Longitude"                     AS store_longitude,
       "Market"                        AS market,
       "Order City"                    AS order_city,
       "Order Country"                 AS order_country,
       "Order Customer Id"             AS order_customer_id,
       "order date (DateOrders)"       AS order_date_raw,
       "Order Id"                      AS order_id,
       "Order Item Cardprod Id"        AS order_item_cardprod_id,
       "Order Item Discount"           AS order_item_discount,
       "Order Item Discount Rate"      AS order_item_discount_rate,
       "Order Item Id"                 AS order_item_id,
       "Order Item Product Price"      AS order_item_product_price,
       "Order Item Profit Ratio"       AS order_item_profit_ratio,
       "Order Item Quantity"           AS order_item_quantity,
       "Sales"                         AS sales,
       "Order Item Total"              AS order_item_total,
       "Order Profit Per Order"        AS order_profit_per_order,
       "Order Region"                  AS order_region,
       "Order State"                   AS order_state,
       "Order Status"                  AS order_status,
       "Order Zipcode"                 AS order_zipcode,
       "Product Card Id"               AS product_card_id,
       "Product Category Id"           AS product_category_id,
       "Product Description"           AS product_description,
       "Product Image"                 AS product_image,
       "Product Name"                  AS product_name,
       "Product Price"                 AS product_price,
       "Product Status"                AS product_status,
       "shipping date (DateOrders)"    AS shipping_date_raw,
       "Shipping Mode"                 AS shipping_mode
FROM read_csv('{{RAW_DIR}}/DataCoSupplyChainDataset.csv', header = true, all_varchar = true);

-- Reference: Spanish -> English country names (164 rows, data/reference/country_es_en.csv, committed)
CREATE OR REPLACE TABLE ref_country AS
SELECT trim(country_es) AS country_es, trim(country_en) AS country_en
FROM read_csv('{{REF_DIR}}/country_es_en.csv', header = true, all_varchar = true);
