# Business insights (validated)

Summary of findings from SQL (`sql/04_business_analysis.sql`) and Python validation (`python/notebooks/Eda_validation.ipynb`). Use as narrative context for Power BI dashboard tooltips and executive summaries.

## Growth drivers

Business growth comes from more sessions, higher session-to-order conversion, and higher average order value—not traffic alone. Revenue per session rises over the period.

## Order value and basket

Average order value steps up around early 2014, aligned with more items per order and a broader product mix.

## Product mix

The Original Mr. Fuzzy dominates early share but declines as a share of items sold; other SKUs gain mix share over time.

## Product value and risk

- **The Original Mr. Fuzzy** — highest items sold, gross revenue, and net revenue; core SKU.
- **The Birthday Sugar Panda** — highest item refund rate; investigate quality, expectations, and messaging.
- **The Forever Love Bear** — solid revenue with relatively lower refund rate; candidate for promotion/cross-sell.

## Marketing and experience

Use source/campaign and device segments from SQL section 2–3 in `04_business_analysis.sql` for “scale vs optimize” decisions. Landing page and funnel sections highlight CRO opportunities (high traffic, below-average conversion).

## Power BI implication

Build dashboard pages that mirror these themes: executive KPIs, monthly performance, marketing, product/refund, funnel/landing.
