# Power BI implementation design

Design for the conversion-analytics semantic model and report. Aligned with `sql/03_kpi_queries.sql`, `sql/04_business_analysis.sql`, `docs/metric_definitions.md`, and validated benchmarks (6.83% conversion, $1,938,509.75 gross revenue, $59.99 AOV, $4.10 revenue per session).

**Recommended mode:** Import from `data/raw/` CSVs (or PostgreSQL views mirroring `sql/00_create_tables.sql`). Disable **Auto date/time** on first load.

---

## 1. Data model

### Design principles

- Two analytical paths: (A) session / traffic / conversion, (B) order / item / product / refund.
- One active relationship path between tables used in the same visual.
- KPIs as **DAX measures**, not implicit sums on fact columns.
- Pre-aggregate funnel and landing in Power Query; do not expose raw pageviews on most report pages.

### Dimension tables

| Table | Source | Grain | Primary key | Role |
|--------|--------|-------|-------------|------|
| **Date** | Generated (`CALENDAR` / Power Query) | Day | `Date` | Mark as date table; hierarchies: Year → Quarter → Month → Date |
| **Product** | `products.csv` | SKU | `product_id` | Product name, launch date |
| **Funnel Step** | PQ derived (unpivot of funnel steps) | Step | `funnel_step_order` | Step label, sort order |
| **Landing Page** | PQ derived | Landing URL | `landing_page` | First page per session |

**Optional (v2):** Marketing Channel bridge (`utm_source` + `utm_campaign` + `utm_content`); thin **User** dimension on `user_id` (no demographics in source data).

### Fact tables

| Table | Source | Grain | Primary key | Foreign keys | Approx. rows |
|--------|--------|-------|-------------|--------------|--------------|
| **Fact Session** | `website_sessions.csv` | Session | `website_session_id` | — | 472,871 |
| **Fact Order** | `orders.csv` | Order | `order_id` | `website_session_id`, `user_id`, `primary_product_id` | 32,313 |
| **Fact Order Item** | `order_items.csv` | Line | `order_item_id` | `order_id`, `product_id` | 40,025 |
| **Fact Refund** | `order_item_refunds.csv` | Refund | `order_item_refund_id` | `order_item_id`, `order_id` | 1,731 |
| **Fact Session Funnel** | PQ from pageviews | Session × step (long) or session flags (wide) | `website_session_id` + step | `website_session_id` | ~473K wide or unpivoted long |
| **Fact Session Landing** | PQ from pageviews | Session | `website_session_id` | `website_session_id` | 472,871 |

**Do not load for standard reporting:** raw **Fact Pageview** — use as PQ staging only (reference query, disable load).

### Date table

Single **Date** table spanning all events (~2012-03 → 2014-12).

| Column | Purpose |
|--------|---------|
| `Date` | Primary key for relationships |
| `Year`, `Quarter`, `Month`, `Month Name`, `Year-Month` | Slicers and axes |

**Role-playing relationships** (one active per page default; others inactive or via `USERELATIONSHIP`):

| From `Date[Date]` | To | Use for |
|-------------------|-----|---------|
| Active (traffic pages) | `Fact Session[session_date]` | Sessions, conversion by visit month |
| Inactive | `Fact Order[order_date]` | Revenue, AOV by order month |
| Inactive | `Fact Order Item[item_date]` | Product trends by line date |
| Inactive | `Fact Refund[refund_date]` | Refund trends by refund month |

Executive default: **session date** for conversion; **order date** for revenue (matches SQL monthly logic in `03_kpi_queries.sql`).

### Relationship diagram

```text
                    ┌──────────── Date ────────────┐
                    │  (multiple inactive roles) │
                    └─────────────┬──────────────┘
                                  │
         ┌────────────────────────┼────────────────────────┐
         ▼                        ▼                        ▼
  Fact Session              Fact Order              Fact Refund
  PK: website_session_id    PK: order_id            PK: order_item_refund_id
         │                        │
         │ 1 : 0..1               │ 1 : *
         └──────────►─────────────┘
                                  │
                                  ▼
                           Fact Order Item
                           PK: order_item_id
                                  │
                    ┌─────────────┴─────────────┐
                    │ * : 1                     │ 0..1 : 1
                    ▼                           ▼
              Dim Product                  Fact Refund
              PK: product_id

  Fact Session 1 : 1 ──► Fact Session Landing
  Fact Session Funnel (long) * : 1 ──► Fact Session
  Dim Funnel Step 1 : * ──► Fact Session Funnel

  DO NOT ACTIVATE: Fact Order[primary_product_id] → Dim Product
  (dedicated measures only; product revenue via Fact Order Item)
```

### Relationship specification

| From | To | Cardinality | Cross-filter | Filter direction | Active |
|------|-----|-------------|--------------|------------------|--------|
| `Fact Session[website_session_id]` | `Fact Order[website_session_id]` | 1:0..1 | Single | Single (Session → Order) | Yes |
| `Fact Order[order_id]` | `Fact Order Item[order_id]` | 1:* | Single | Single (Order → Item) | Yes |
| `Fact Order Item[order_item_id]` | `Fact Refund[order_item_id]` | 1:0..1 | Single | Single (Item → Refund) | Yes |
| `Dim Product[product_id]` | `Fact Order Item[product_id]` | 1:* | Single | Single (Product → Item) | Yes |
| `Date[Date]` | `Fact Session[session_date]` | *:1 | Single | Single | Yes (default) |
| `Date[Date]` | `Fact Order[order_date]` | *:1 | Single | Single | No |
| `Date[Date]` | `Fact Order Item[item_date]` | *:1 | Single | Single | No |
| `Date[Date]` | `Fact Refund[refund_date]` | *:1 | Single | Single | No |
| `Fact Session[website_session_id]` | `Fact Session Landing[website_session_id]` | 1:1 | Both | Single | Yes |
| `Fact Session[website_session_id]` | `Fact Session Funnel[website_session_id]` | 1:* | Single | Single | Yes (long format) |
| `Dim Funnel Step[funnel_step_order]` | `Fact Session Funnel[funnel_step_order]` | 1:* | Single | Single | Yes |

**Hide from report view:** surrogate keys (`website_session_id`, `order_id`, `order_item_id`, `product_id`, `user_id`, `primary_product_id`, refund keys).

---

## 2. Power Query preparation

### Load strategy

| Source | Action |
|--------|--------|
| `website_sessions.csv` | Load → **Fact Session** |
| `orders.csv` | Load → **Fact Order** |
| `order_items.csv` | Load → **Fact Order Item** |
| `order_item_refunds.csv` | Load → **Fact Refund** |
| `products.csv` | Load → **Dim Product** |
| `website_pageviews.csv` | Reference only → funnel + landing → **disable load** on raw pageviews |
| `maven_fuzzy_factory_data_dictionary.csv` | Do not load |

### Data type changes

| Column | Target type |
|--------|-------------|
| All `*_id` | Whole Number (Int64) |
| `price_usd`, `cogs_usd`, `refund_amount_usd` | Fixed decimal / Currency (2 decimals) |
| All `created_at` | Date/Time |
| `items_purchased` | Whole Number |
| `is_repeat_session`, `is_primary_item` | **Boolean** (`_ = 1`) |

### Boolean transformation

```powerquery
= Table.TransformColumns(Source, {{"is_repeat_session", each _ = 1, type logical}})
```

Apply to `Fact Session[is_repeat_session]` and `Fact Order Item[is_primary_item]`. Optional: `Session Type` = "Repeat" / "New".

### Date columns (add in PQ)

| Table | Column | Formula |
|--------|--------|---------|
| Fact Session | `session_date` | `DateTime.Date([created_at])` |
| Fact Order | `order_date` | `DateTime.Date([created_at])` |
| Fact Order Item | `item_date` | `DateTime.Date([created_at])` |
| Fact Refund | `refund_date` | `DateTime.Date([created_at])` |

### Null / blank handling (match SQL)

| Field | Replacement |
|--------|-------------|
| `utm_source` | `"direct_or_none"` |
| `utm_campaign` | `"no_campaign"` |
| `utm_content` | `"no_content"` |

### Columns to hide or remove from report

- Raw pageviews table (entire query disabled for load).
- `primary_product_id` on orders (keep for optional measures; hide from report).
- Redundant `order_id` on refunds after validation (optional remove from model).
- Duplicate `created_at` if only `*_date` is used in relationships.

### Derived tables

**Fact Session Landing** (mirror `sql/04_business_analysis.sql` §5)

1. Sort pageviews by `website_session_id`, `created_at`, `website_pageview_id`.
2. First row per session → `landing_page` = `pageview_url`.
3. Prefer earliest `created_at`; min `website_pageview_id` is equivalent in this dataset.

**Fact Session Funnel** (mirror `sql/04_business_analysis.sql` §6)

Session-level flags from `pageview_url`, then unpivot to long format or load a **Funnel Benchmark** snapshot table for exact SQL parity.

| Step order | Step key | URLs |
|------------|----------|------|
| 1 | session_started | all sessions |
| 2 | reached_products | `/products` |
| 3 | reached_product_detail | `/the-original-mr-fuzzy`, `/the-forever-love-bear`, `/the-birthday-sugar-panda`, `/the-hudson-river-mini-bear` |
| 4 | reached_cart | `/cart` |
| 5 | reached_shipping | `/shipping` |
| 6 | reached_billing | `/billing`, `/billing-2` |
| 7 | completed_order | `/thank-you-for-your-order` |

**Dim Funnel Step:** static table with `funnel_step_order`, `funnel_step`, friendly labels.

**Date:** `Calendar` from `#date(2012,3,1)` through `#date(2014,12,31)`.

---

## 3. DAX measures

Organize in display folders: `_Metrics`, `Traffic`, `Orders & Revenue`, `Margin`, `Refunds`, `Product`, `Funnel`, `Channel`, `Behavior`. Use a blank `_Metrics` table or host by domain on fact tables.

### Traffic & sessions

```dax
Total Sessions = COUNTROWS ( 'Fact Session' )

New Sessions =
    CALCULATE ( [Total Sessions], 'Fact Session'[is_repeat_session] = FALSE )

Repeat Sessions =
    CALCULATE ( [Total Sessions], 'Fact Session'[is_repeat_session] = TRUE )

Repeat Session Share = DIVIDE ( [Repeat Sessions], [Total Sessions] )
```

### Orders & conversion

```dax
Total Orders = COUNTROWS ( 'Fact Order' )

Conversion Rate = DIVIDE ( [Total Orders], [Total Sessions] )

Session Conversion Rate (channel context) =
    DIVIDE (
        CALCULATE ( DISTINCTCOUNT ( 'Fact Order'[order_id] ) ),
        [Total Sessions]
    )
```

**Benchmark:** conversion ≈ **6.83%**.

### Revenue & AOV

```dax
Gross Revenue = SUM ( 'Fact Order'[price_usd] )

Gross Revenue (Order Date) =
    CALCULATE (
        [Gross Revenue],
        USERELATIONSHIP ( 'Date'[Date], 'Fact Order'[order_date] )
    )

Average Order Value = DIVIDE ( [Gross Revenue], [Total Orders] )

Revenue per Session = DIVIDE ( [Gross Revenue], [Total Sessions] )

Net Revenue = [Gross Revenue] - [Refund Amount]

Net Revenue per Session = DIVIDE ( [Net Revenue], [Total Sessions] )
```

**Benchmarks:** gross **$1,938,509.75** | AOV **$59.99** | RPS **$4.10** | net **$1,853,171.06**.

### Margin

```dax
Gross Margin =
    SUMX ( 'Fact Order', 'Fact Order'[price_usd] - 'Fact Order'[cogs_usd] )

Gross Margin Rate = DIVIDE ( [Gross Margin], [Gross Revenue] )
```

**Benchmark:** margin rate ≈ **62.74%**.

### Refunds

```dax
Refund Amount = SUM ( 'Fact Refund'[refund_amount_usd] )

Refunded Items = COUNTROWS ( 'Fact Refund' )

Refunded Orders = DISTINCTCOUNT ( 'Fact Refund'[order_id] )

Refund Share of Revenue = DIVIDE ( [Refund Amount], [Gross Revenue] )

Refund Order Rate = DIVIDE ( [Refunded Orders], [Total Orders] )
```

**Benchmark:** refund amount **$85,338.69**.

### Product performance

```dax
Items Sold = COUNTROWS ( 'Fact Order Item' )

Product Gross Revenue = SUM ( 'Fact Order Item'[price_usd] )

Product Net Revenue = [Product Gross Revenue] - [Product Refund Amount]

Product Refund Amount = SUM ( 'Fact Refund'[refund_amount_usd] )

Item Refund Rate = DIVIDE ( [Refunded Items], [Items Sold] )

Product Mix % (Items) =
    DIVIDE (
        [Items Sold],
        CALCULATE ( [Items Sold], ALLSELECTED ( 'Dim Product' ) )
    )
```

### Channel performance

```dax
Channel Conversion Rate =
    DIVIDE (
        CALCULATE ( DISTINCTCOUNT ( 'Fact Order'[order_id] ) ),
        [Total Sessions]
    )

Channel Revenue per Session = DIVIDE ( [Gross Revenue], [Total Sessions] )
```

### Funnel

Prefer PQ snapshot mirroring SQL funnel output for v1 parity, or measures on long `Fact Session Funnel` with disclaimer: steps are **non-exclusive** (not a strict path funnel).

### Repeat sessions / users

```dax
Orders from Repeat Sessions =
    CALCULATE ( [Total Orders], 'Fact Session'[is_repeat_session] = TRUE )

Repeat Session Conversion Rate =
    DIVIDE ( [Orders from Repeat Sessions], [Repeat Sessions] )

Distinct Users (Sessions) = DISTINCTCOUNT ( 'Fact Session'[user_id] )
```

No customer master table — repeat analysis uses `is_repeat_session` only.

---

## 4. Report pages

| Page | Focus | Key visuals |
|------|--------|-------------|
| **1. Executive overview** | KPIs + trends | Cards: sessions, orders, conversion %, gross/net revenue, RPS, margin %, refund share; monthly sessions/orders/revenue |
| **2. Traffic & conversion** | Acquisition | Sessions over time; conversion by month; bars/matrix by UTM source/campaign; device share |
| **3. Funnel analysis** | CRO | 7-step funnel from SQL; drop-off %; largest leak callout |
| **4. Landing pages** | Entry points | Sessions by landing page; conversion vs site average |
| **5. Revenue analysis** | Monetization | Gross/net revenue, AOV, RPS trends; revenue by channel/device |
| **6. Product performance** | Merchandising | Revenue, net revenue, mix %, items sold; highlight refund-risk SKU |
| **7. Refund analysis** | Risk | Refund amount, share of revenue, item refund rate by product |
| **8. Session behavior** | Loyalty | New vs repeat sessions; repeat conversion; items per order |

**Global UX:** synced date/device/source slicers; bookmark for gross vs net; field parameters on trend charts; definitions from `docs/metric_definitions.md` in tooltips or a definitions page.

Maps to `docs/business_questions.md` and narrative in `docs/business_insights.md`.

---

## 5. Portfolio assessment

### Strengths

- Realistic ecommerce model with validated SQL/Python KPIs.
- Documented grain rules and data quality (`sql/02_data_quality_checks.sql`).
- Scale (~1.2M pageviews) credible for Import mode.
- Funnel, landing, and channel segmentation ready for visuals.

### Gap today

Documentation and SQL/Python are complete; **`.pbix`, DAX, and report pages are not built yet**.

### What makes the portfolio stronger

| Priority | Action |
|----------|--------|
| Must-have | Publish `.pbix` with star schema, 15+ measures, 6–8 pages |
| Must-have | KPI reconciliation table vs `sql/03_kpi_queries.sql` / notebook |
| High | PQ funnel + landing tables (not only imported SQL CSV) |
| High | `USERELATIONSHIP` for session vs order date on one report |
| Medium | Publish to Service / Fabric + refresh notes |
| Nice | Field parameters, drill-through, mobile layout |

### Positioning line

> Built a validated ecommerce conversion model in SQL/Python (~473K sessions, $1.9M revenue), then implemented a star-schema Power BI model with DAX measures reconciled to SQL benchmarks.

---

## Implementation checklist

1. Power Query: load facts/dims, booleans, dates, UTM null handling.
2. PQ: landing + funnel derived tables; disable raw pageviews load.
3. Model: relationships, hide keys, mark `Date`, disable auto date/time.
4. DAX: traffic → orders → conversion → revenue → refunds → product.
5. Validate KPIs against SQL/Python on a summary page.
6. Build eight report pages; sync slicers; add definition tooltips.
7. Save `.pbix` in `powerbi/`; document reconciliation in project README.
