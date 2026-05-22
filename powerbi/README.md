# Power BI

Build the semantic model and report here (`.pbix` or Fabric artifacts). Full specification: **[implementation_design.md](implementation_design.md)**.

## Before you start

- Source data: `data/raw/*.csv` (or PostgreSQL tables from `sql/00_create_tables.sql`).
- KPI rules: `docs/metric_definitions.md`.
- SQL/Python benchmarks: `sql/03_kpi_queries.sql`, `python/notebooks/Eda_validation.ipynb`.

On first import: **File → Options → disable Auto date/time**.

## Build order

1. **Power Query** — Load sessions, orders, order items, refunds, products. Reference pageviews only; build **Fact Session Landing** and **Fact Session Funnel** (or funnel snapshot); disable load on raw pageviews. Cast `0`/`1` flags to Boolean; add `session_date`, `order_date`, `item_date`, `refund_date`; replace blank UTMs per design doc.
2. **Date table** — Calendar 2012-03-01 through 2014-12-31; mark as date table.
3. **Model** — Create relationships in [implementation_design.md §1](implementation_design.md#1-data-model). Hide keys. Do **not** activate `orders[primary_product_id]` → `products` for product revenue.
4. **DAX** — Add measures from [implementation_design.md §3](implementation_design.md#3-dax-measures). Reconcile cards to benchmarks (6.83% conversion, $1.94M gross revenue, $59.99 AOV, $4.10 RPS).
5. **Report** — Eight pages listed in [implementation_design.md §4](implementation_design.md#4-report-pages). Sync date/device/source slicers across pages.

## Validation targets

| Measure | Expected (full period) |
|---------|------------------------|
| Conversion rate | 6.83% |
| Gross revenue | $1,938,509.75 |
| Average order value | $59.99 |
| Revenue per session | $4.10 |
| Net revenue | $1,853,171.06 |
| Gross margin rate | 62.74% |
| Refund amount | $85,338.69 |

## Artifacts to add here

- `conversion_analytics.pbix` (or your report name)
- Optional: screenshots or a short validation note after KPI reconciliation
