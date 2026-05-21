# Power BI layer (planned)

This folder is reserved for the Power BI semantic model and report files (`.pbix` or Fabric artifacts).

## Recommended import path

1. Load CSVs from `data/raw/` (or a PostgreSQL view layer mirroring `sql/00_create_tables.sql`).
2. Build a star schema in Power Query before loading to the model (see project README and `docs/metric_definitions.md`).
3. Mark `products` and a generated `Date` table as dimensions; mark fact tables at the correct grain.
4. Implement KPIs as DAX measures on the appropriate fact table—avoid importing pre-aggregated SQL result sets as facts unless they are snapshot tables.

## Relationships (active, single-direction)

- `website_sessions[website_session_id]` → `website_pageviews[website_session_id]` (1:*)
- `website_sessions[website_session_id]` → `orders[website_session_id]` (1:0..1)
- `orders[order_id]` → `order_items[order_id]` (1:*)
- `order_items[order_item_id]` → `order_item_refunds[order_item_id]` (1:0..1)
- `products[product_id]` → `order_items[product_id]` (1:*)

Hide foreign keys from report view where possible. Do not relate `orders` directly to `products` for revenue totals if `order_items` is the product fact—use `primary_product_id` only for bundle-oriented analysis.

## Performance notes

- `website_pageviews` (~1.2M rows) is acceptable in Power BI Desktop; for funnel/landing analysis consider a pre-built session-level funnel table in Power Query.
- Disable auto date/time on import; use one `Date` table with relationships to session, order, item, and refund dates as needed (role-playing or separate date columns).

## Validation

Reconcile card visuals to SQL/Python benchmarks in `sql/03_kpi_queries.sql` and `python/notebooks/Eda_validation.ipynb` before publishing.
