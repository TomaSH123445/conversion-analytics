# Metric definitions

Canonical KPI definitions aligned with `sql/03_kpi_queries.sql` and `python/notebooks/Eda_validation.ipynb`. Use these rules in Power BI (DAX) so results match SQL/Python validation.

| Metric | Numerator | Denominator | Filters / grain | Notes |
|--------|-----------|-------------|-----------------|-------|
| Total sessions | `COUNT(website_session_id)` | — | `website_sessions`; session grain | Traffic volume. |
| Total orders | `COUNT(order_id)` | — | `orders`; order grain | Completed orders only (table definition). |
| Session-to-order conversion rate | Total orders | Total sessions | Global or by dimension after filtering sessions | Valid because max 1 order per session. Use `DISTINCTCOUNT` for orders when joining sessions to orders. |
| Gross revenue | `SUM(price_usd)` | — | `orders` for order-level; `order_items` for product-level | Do not mix grains in one visual without a clear fact table. |
| Net revenue | Gross revenue − total refund amount | — | Order-level net uses order revenue minus refunds attributed to those orders; product-level net uses item revenue minus item refunds | Refunds come from `order_item_refunds`. |
| Average order value (AOV) | Gross revenue | Total orders | Order grain | Not item count. |
| Revenue per session | Gross revenue | Total sessions | Session grain | Uses all sessions in denominator, including non-converting. |
| Net revenue per session | Net revenue | Total sessions | Session grain | Same denominator as revenue per session. |
| Gross margin | `SUM(price_usd - cogs_usd)` | — | Match revenue grain (`orders` or `order_items`) | |
| Gross margin rate | Gross margin | Gross revenue | Same grain as margin | Express as % in reports. |
| Refund amount | `SUM(refund_amount_usd)` | — | `order_item_refunds` | |
| Refund share of revenue | Total refund amount | Gross revenue | Order-level gross revenue | Also called refund % of revenue. |
| Refund order rate | Distinct refunded orders | Total orders | Orders with ≥1 refunded line | Different from item refund rate. |
| Item refund rate | Refunded items | Items sold | `order_items` + `order_item_refunds` | Product analysis grain; max 1 refund per item in this dataset. |
| Items sold | `COUNT(order_item_id)` | — | `order_items` | One row ≈ one unit. |
| Monthly conversion rate | Orders in month | Sessions in month | Align `created_at` month on sessions vs orders separately, then join months | Do not truncate session dates using order month. |
| Funnel step conversion | Sessions reaching step | Sessions reaching previous step (or all sessions for step 1) | Session-level flags from `website_pageviews` | Define step URLs explicitly; sequential steps are not mutually exclusive paths. |
| Landing page conversion | Orders from sessions whose first pageview matches landing URL | Sessions with that landing page | First pageview = `MIN(website_pageview_id)` per session (validated equal to earliest `created_at` in this dataset) | Prefer earliest timestamp in production if IDs are not time-ordered. |

**Attribution:** Marketing metrics (`utm_source`, `utm_campaign`, `utm_content`, `device_type`) live on `website_sessions`. Join `orders` on `website_session_id` with a left join from sessions when conversion or revenue per session is required.

**Product vs order revenue:** Header `orders.price_usd` equals the sum of child `order_items` in this dataset. Use `order_items` for mix, units, and item refunds; use `orders` for session conversion and AOV.
