# Build guide (Power BI Desktop, Windows)

No `.pbix` is committed: this repo is built on Linux and Power BI Desktop runs on Windows only.

1. `python scripts/download_full_data.py` then `python run_pipeline.py --source full` (or use the committed `powerbi/data/*.csv`, which are already full size, ~40 MB total).
2. Power BI Desktop > Get data > Text/CSV: load the eight CSVs in `powerbi/data/` (UTF-8). In Power Query set the key columns (`order_id`, `order_item_id`, `customer_id`, `product_id`, `geo_key`, `shipping_mode_key`, `status_key`), day counts and all `is_*` / `late_flag` columns to Whole number; money and rate columns to Decimal; `order_date`, `ship_date`, `date_key` to Date.
3. Model view: create the relationships in `model.md`. Set `fact_order_item -> fact_order` to cross-filter **Both**. Mark `dim_date` as a date table.
4. New measures: paste `measures.dax` one measure at a time (order-grain measures into fact_order, line-grain ones into fact_order_item).
5. Build the page in `dashboard_spec.md` and check the cards against the "Expected" column; they come from `results/metrics.json`.
6. Save as `da-learn-10-supply-chain.pbix` locally (do not commit the binary unless you want to).
