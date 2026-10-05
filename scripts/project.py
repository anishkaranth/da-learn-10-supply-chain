"""Project-specific settings used by run_pipeline.py (raw files, star / clean tables, JSON.shot content)."""
NAME = "da-learn-10-supply-chain"
DATASET = ("DataCo Smart Supply Chain for Big Data Analysis (Constante, Silva & Pereira, Mendeley Data v5, "
           "doi:10.17632/8gx2fvg2k6.5; Kaggle: shashwatwork/dataco-smart-supply-chain-for-big-data-analysis)")
RAW_FILES = ["DataCoSupplyChainDataset.csv"]
STAR = ["fact_order_item", "fact_order", "dim_customer", "dim_product", "dim_geography", "dim_shipping_mode",
        "dim_order_status", "dim_date"]
CLEAN = ["cln_order_items", "cln_orders"]
METRIC_TABLES = ["a_delivery_by_mode", "a_late_by_mode_market", "a_delay_distribution", "a_market_summary",
                 "a_region_summary", "a_country_top", "a_department_summary", "a_category_summary", "a_top_products",
                 "a_product_concentration", "a_discount_vs_margin", "a_late_vs_profit", "a_payment_status",
                 "a_fraud_by_region", "a_monthly_trend", "a_yearly_summary", "a_segment_summary"]


def build_shot(q, kpi):
    """Headline snapshot written to results/JSON.shot."""
    return {
        "config": {"sql_dialect": "Spark SQL style (+ DuckDB shims in sql/00), run on DuckDB",
                   "grain": "fact_order_item = one row per order line; fact_order = one row per order",
                   "booked_rule": "money KPIs exclude order_status CANCELED and SUSPECTED_FRAUD",
                   "late_rule": "late = Days for shipping (real) > Days for shipment (scheduled); delivery KPIs exclude 'Shipping canceled'",
                   "net_sales": "Order Item Total (Sales - Order Item Discount)",
                   "outlier_rule": "line profit outside Q1/Q3 -/+ 3*IQR (flagged, kept)",
                   "regime_flag": "orders from 2017-10-01 flagged is_late_2017_regime (1 line per order, few products)",
                   "sample_rule": "order_id % 200 = 7 plus every order containing an address-shifted row (data/raw)"},
        "headline": kpi,
        "delivery_by_mode": q("SELECT shipping_mode, promised_days, avg_actual_days, late_pct, shipped_orders FROM a_delivery_by_mode ORDER BY promised_days"),
        "markets": q("SELECT market, orders, booked_net_sales, margin_pct, late_pct, suspected_fraud_pct FROM a_market_summary ORDER BY booked_net_sales DESC"),
        "departments_by_sales": q("SELECT department_name, sales_share_pct, margin_pct, loss_line_pct FROM a_department_summary ORDER BY net_sales DESC LIMIT 6"),
        "discount_vs_margin": q("SELECT discount_band, avg_discount_rate_pct, margin_pct, loss_line_pct FROM a_discount_vs_margin ORDER BY discount_band"),
        "top_products": q("SELECT product_name, net_sales, sales_share_pct, margin_pct FROM a_top_products WHERE rank_by_sales <= 5 ORDER BY rank_by_sales"),
        "product_concentration": q("SELECT * FROM a_product_concentration")[0],
        "yearly": q("SELECT year, orders, booked_net_sales, margin_pct, late_pct FROM a_yearly_summary ORDER BY year"),
    }
