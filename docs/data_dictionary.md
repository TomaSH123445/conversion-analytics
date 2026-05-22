# Data dictionary

Source: CSV extracts in `data/raw/` (Maven Analytics *Fuzzy Factory* style ecommerce dataset). Field-level text from the course bundle is mirrored in `data/raw/maven_fuzzy_factory_data_dictionary.csv`.

---

## `orders` (`orders.csv`)

| | |
|---|---|
| **Grain** | One row per completed order. |
| **Primary key** | `order_id` |
| **Foreign keys** | `website_session_id` → `website_sessions.website_session_id`; `user_id` → logical user (no `users` table in extract); `primary_product_id` → `products.product_id` (primary line in bundle context). |
| **Business use** | Order volume, revenue (`price_usd`), gross margin vs COGS (`cogs_usd`), basket size (`items_purchased`), tying purchases to acquisition session and user for conversion and cohort work. |
| **Risk / caveats** | Revenue and margin at order header may not equal the sum of `order_items` if bundles/discounts differ; use `order_items` for product mix. `primary_product_id` is only the “primary” SKU when the order is treated as a bundle—validate joins for multi-item orders. Refunds are not on this table; net revenue needs `order_item_refunds`. |

**Important columns**

| Column | Role |
|--------|------|
| `order_id` | Surrogate PK. |
| `created_at` | Order time; funnel and time-series grain. |
| `website_session_id` | Attribution of order to browsing session. |
| `user_id` | Stable-ish customer key across sessions (no demographic table). |
| `primary_product_id` | Main product for bundle-oriented reporting. |
| `items_purchased` | Line count / basket depth at order level. |
| `price_usd` | Order total revenue. |
| `cogs_usd` | Order-level COGS. |

---

## `order_items` (`order_items.csv`)

| | |
|---|---|
| **Grain** | One row per product line on an order (one SKU line). |
| **Primary key** | `order_item_id` |
| **Foreign keys** | `order_id` → `orders.order_id`; `product_id` → `products.product_id`. |
| **Business use** | Product-level revenue and margin, units implied per row (typically one unit per line unless business rules say otherwise), primary vs add-on items via `is_primary_item`, basket composition and attach rates. |
| **Risk / caveats** | Sum of `price_usd` / `cogs_usd` across items should be reconciled to `orders.price_usd` / `orders.cogs_usd` where business rules expect equality. `is_primary_item` is binary; clarify definition before filtering “main” product. |

**Important columns**

| Column | Role |
|--------|------|
| `order_item_id` | PK for line-level refunds and joins. |
| `created_at` | Often mirrors order time; confirm if used as event time. |
| `order_id` | Parent order. |
| `product_id` | Product dimension. |
| `is_primary_item` | Flags primary line in bundle-oriented logic (`0` or `1`). |
| `price_usd`, `cogs_usd` | Line revenue and COGS. |

---

## `order_item_refunds` (`order_item_refunds.csv`)

| | |
|---|---|
| **Grain** | One row per refund transaction on a specific order line (and denormalized order). |
| **Primary key** | `order_item_refund_id` |
| **Foreign keys** | `order_item_id` → `order_items.order_item_id`; `order_id` → `orders.order_id` (denormalized copy for convenience). |
| **Business use** | Net sales after refunds, refund rate, time-to-refund from order or item date, loss of margin on returned lines. |
| **Risk / caveats** | Refund amount may not always match original line `price_usd` (partial refunds, fees—validate). `order_id` is redundant with `order_items`; mismatches would indicate data quality issues. |

**Important columns**

| Column | Role |
|--------|------|
| `order_item_refund_id` | PK. |
| `created_at` | Refund event time. |
| `order_item_id` | Which line was refunded. |
| `order_id` | Parent order (shortcut). |
| `refund_amount_usd` | Cash impact of refund. |

---

## `products` (`products.csv`)

| | |
|---|---|
| **Grain** | One row per sellable product (SKU / product master). |
| **Primary key** | `product_id` |
| **Foreign keys** | None in extract; referenced by `orders.primary_product_id`, `order_items.product_id`. |
| **Business use** | Product catalog for reporting names, launches (`created_at`), merchandising and mix analysis. |
| **Risk / caveats** | Small static catalog in sample; production systems often need SCD2 or effective dating not present here. |

**Important columns**

| Column | Role |
|--------|------|
| `product_id` | PK used across facts. |
| `created_at` | Launch or record creation time. |
| `product_name` | Display / reporting label. |

---

## `website_sessions` (`website_sessions.csv`)

| | |
|---|---|
| **Grain** | One row per website session (browser visit instance). |
| **Primary key** | `website_session_id` |
| **Foreign keys** | `user_id` → logical user (same as orders; no `users` entity file). |
| **Business use** | Traffic and marketing attribution (`utm_*`, `http_referer`), device split (`device_type`), new vs returning (`is_repeat_session`), session-to-order conversion when joined to `orders`. |
| **Risk / caveats** | UTM and referer are client-supplied and can be stripped, wrong, or inconsistent; last-click bias if used as sole attribution. `is_repeat_session` depends on prior history in the dataset window. Stored as `0`/`1` in CSV—use Boolean in Power BI. |

**Important columns**

| Column | Role |
|--------|------|
| `website_session_id` | PK; join to pageviews and orders. |
| `created_at` | Session start. |
| `user_id` | Visitor key. |
| `is_repeat_session` | Repeat vs first session flag (`0` or `1`). |
| `utm_source`, `utm_campaign`, `utm_content` | Campaign hierarchy. |
| `device_type` | Mobile vs desktop (coarse). |
| `http_referer` | Referring URL string. |

---

## `website_pageviews` (`website_pageviews.csv`)

| | |
|---|---|
| **Grain** | One row per page view event within a session. |
| **Primary key** | `website_pageview_id` |
| **Foreign keys** | `website_session_id` → `website_sessions.website_session_id`. |
| **Business use** | Funnel steps by `pageview_url`, path analysis, engagement before purchase, landing page performance when joined to sessions and orders. |
| **Risk / caveats** | Volume is large relative to orders; sampling or aggregation needed for ad hoc tools. Same session can hit many URLs; dedupe rules for “unique step” funnels must be defined. Iframe or SPA tracking gaps are not modeled. |

**Important columns**

| Column | Role |
|--------|------|
| `website_pageview_id` | PK. |
| `created_at` | Event time (sequence within session). |
| `website_session_id` | Parent session. |
| `pageview_url` | Path or URL fragment for journey logic. |

---

## Entity relationship (logical)

```text
website_sessions (website_session_id) ──┬── website_pageviews
                                        │
                                        └── orders ──┬── order_items ─── order_item_refunds
                                                     │
products (product_id) ◄──────────────────────────────┘
         (also orders.primary_product_id)
```

`user_id` links `website_sessions` and `orders` without a separate user dimension table in this extract.
