#!/usr/bin/env python3
"""Render SVG charts (pure vector shapes, no raster) from the KPI tables exported by run_pipeline.py."""
import csv, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import svgcharts as S


def rd(t, name):
    with open(pathlib.Path(t) / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def f(x):
    return float(x) if x not in ("", None) else 0.0


MODES = ["Same Day", "First Class", "Second Class", "Standard Class"]


def panels(t):
    k = rd(t, "a_kpi_headline")[0]
    mode = sorted(rd(t, "a_delivery_by_mode"), key=lambda r: f(r["promised_days"]))
    mm = {(r["market"], r["shipping_mode"]): f(r["late_pct"]) for r in rd(t, "a_late_by_mode_market")}
    markets = sorted({m for m, _ in mm})
    delay = sorted(rd(t, "a_delay_distribution"), key=lambda r: int(r["delay_days"]))
    dept = sorted(rd(t, "a_department_summary"), key=lambda r: -f(r["net_sales"]))
    month = sorted(rd(t, "a_monthly_trend"), key=lambda r: r["year_month"])
    disc = sorted(rd(t, "a_discount_vs_margin"), key=lambda r: r["discount_band"])
    prod = sorted(rd(t, "a_top_products"), key=lambda r: int(r["rank_by_sales"]))[:10]
    pay = {}
    for r in rd(t, "a_payment_status"):
        d = pay.setdefault(r["payment_type"], [0, 0]); d[0] += f(r["orders"])
        if r["order_status"] == "SUSPECTED_FRAUD": d[1] += f(r["orders"])
    pays = sorted(pay, key=lambda p: -pay[p][1] / pay[p][0])
    shipped = sum(int(f(r["shipped_orders"])) for r in mode)
    return [
        ("late_rate_by_shipping_mode", S.vbar("Late-delivery rate by shipping mode (shipped orders)", [r["shipping_mode"] for r in mode],
                                              [f(r["late_pct"]) for r in mode], "{:.1f}%",
                                              f"{shipped:,} shipped orders; late = actual days > promised days", ylabel="% of orders late",
                                              color=[S.PALETTE[1], S.PALETTE[1], S.PALETTE[0], S.PALETTE[0]],
                                              notes=[f"promised {int(f(r['promised_days']))}d, actual {f(r['avg_actual_days']):.2f}d" for r in mode], vmax=120)),
        ("late_rate_by_market_and_mode", S.grouped_vbar("Late rate by market and shipping mode", markets,
                                                        [(m, [mm.get((mk, m), 0.0) for mk in markets]) for m in MODES], "{:.0f}",
                                                        "the pattern is the same in every market: lateness follows the service level",
                                                        ylabel="% late")),
        ("delay_distribution", S.vbar("Actual minus promised shipping days", [f"{int(r['delay_days']):+d}" if int(r["delay_days"]) else "0" for r in delay],
                                      [f(r["share_pct"]) for r in delay], "{:.1f}%", "share of shipped orders; positive = late",
                                      color=[S.PALETTE[2] if int(r["delay_days"]) <= 0 else S.PALETTE[1] for r in delay],
                                      ylabel="% of shipped orders")),
        ("sales_by_department", S.hbar("Booked net sales by department ($M)", [r["department_name"] for r in dept],
                                       [f(r["net_sales"]) / 1e6 for r in dept], "${:.2f}M", "label: share of sales, profit margin",
                                       notes=[f"{f(r['sales_share_pct']):.1f}%, margin {f(r['margin_pct']):.1f}%" for r in dept], vmax=22)),
        ("monthly_sales_trend", S.line("Booked net sales by month ($k)", [r["year_month"] for r in month],
                                       [("net sales $k", [f(r["booked_net_sales"]) / 1e3 for r in month])], "{:,.0f}",
                                       "flat ~$0.89M a month 2015 to Sep 2017; from Oct 2017 the file holds 1 line per order", every=6,
                                       xlabel="order month")),
        ("discount_vs_margin", S.grouped_vbar("Discount band vs profit margin and loss-making lines", [r["discount_band"][2:] for r in disc],
                                              [("profit margin %", [f(r["margin_pct"]) for r in disc]),
                                               ("loss-making lines %", [f(r["loss_line_pct"]) for r in disc])], "{:.1f}",
                                              "booked lines; deeper discounts do not change margin or loss rate", ylabel="%")),
        ("top_products", S.hbar("Top 10 products by booked net sales ($M)", [r["product_name"][:38] for r in prod],
                                [f(r["net_sales"]) / 1e6 for r in prod], "${:.2f}M", "label: share of all booked sales", color=S.PALETTE[2],
                                notes=[f"{f(r['sales_share_pct']):.1f}%" for r in prod])),
        ("fraud_by_payment_type", S.vbar("Suspected-fraud orders by payment type", pays,
                                         [100 * pay[p][1] / pay[p][0] for p in pays], "{:.2f}%",
                                         f"{int(sum(v[1] for v in pay.values())):,} suspected-fraud orders, all paid by bank transfer",
                                         color=S.PALETTE[4], notes=[f"n={int(pay[p][0]):,}" for p in pays], ylabel="% of orders", vmax=10)),
    ], k


def make_all(tables, out):
    out = pathlib.Path(out); out.mkdir(parents=True, exist_ok=True)
    ps, k = panels(tables)
    for name, p in ps:
        S.save(p, out / f"{name}.svg")
    cards = [("Orders", f"{int(f(k['orders_total'])):,}"), ("Order lines", f"{int(f(k['order_lines_total'])):,}"),
             ("Booked net sales", f"${f(k['booked_net_sales']) / 1e6:.2f}M"), ("Profit margin", f"{f(k['profit_margin_pct']):.2f}%"),
             ("Late orders", f"{f(k['late_order_pct']):.2f}%"), ("Loss-making lines", f"{f(k['loss_line_pct']):.2f}%"),
             ("Suspected fraud", f"{f(k['suspected_fraud_order_pct']):.2f}%")]
    dash = [p for n, p in ps if n in ("late_rate_by_shipping_mode", "late_rate_by_market_and_mode", "sales_by_department",
                                      "monthly_sales_trend", "discount_vs_margin", "top_products")]
    S.dashboard(out / "dashboard.svg", "DataCo supply chain: delivery promise vs reality, sales, margin and risk",
                f"Rendered from results/tables (SQL on DuckDB). Orders {k['first_order_date']} to {k['last_order_date']}; "
                "money = booked orders (no canceled / suspected fraud).", cards, dash, cols=2)
    print("charts ->", out, sorted(p.name for p in out.glob("*.svg")))


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parents[1]
    make_all(root / "results/tables", root / "results/images")
