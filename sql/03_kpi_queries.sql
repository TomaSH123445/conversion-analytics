-- ============================================================
-- Purpose:
-- Calculate core e-commerce KPIs for traffic, conversion,
-- revenue, margin, refunds, channel performance, device performance,
-- and product performance.
-- Landing page and funnel metrics: see sql/04_business_analysis.sql.
--

-- ============================================================
-- 1. Core KPI summary
-- ============================================================
-- What this query calculates:
-- Creates a compact overview of the most important business KPIs.
--
-- Why it matters:
-- This query gives a first executive-level view of traffic,
-- conversion, revenue, margin and refunds.

WITH sessions AS (
    SELECT
        COUNT(*) AS total_sessions
    FROM website_sessions
),

orders_summary AS (
    SELECT
        COUNT(*) AS total_orders,
        SUM(price_usd) AS gross_revenue,
        SUM(cogs_usd) AS total_cogs,
        SUM(price_usd - cogs_usd) AS gross_margin
    FROM orders
),

refunds AS (
    SELECT
        COUNT(*) AS total_refund_items,
        COUNT(DISTINCT order_id) AS refunded_orders,
        COALESCE(SUM(refund_amount_usd), 0) AS total_refund_amount
    FROM order_item_refunds
)

SELECT
    'total_sessions' AS metric_name,
    total_sessions::numeric AS metric_value
FROM sessions

UNION ALL

SELECT
    'total_orders',
    total_orders::numeric
FROM orders_summary

UNION ALL

SELECT
    'session_to_order_conversion_rate_pct',
    ROUND(total_orders::numeric / total_sessions * 100, 2)
FROM sessions
CROSS JOIN orders_summary

UNION ALL

SELECT
    'gross_revenue',
    ROUND(gross_revenue, 2)
FROM orders_summary

UNION ALL

SELECT
    'total_refund_amount',
    ROUND(total_refund_amount, 2)
FROM refunds

UNION ALL

SELECT
    'net_revenue',
    ROUND(gross_revenue - total_refund_amount, 2)
FROM orders_summary
CROSS JOIN refunds

UNION ALL

SELECT
    'average_order_value',
    ROUND(gross_revenue::numeric / total_orders, 2)
FROM orders_summary

UNION ALL

SELECT
    'revenue_per_session',
    ROUND(gross_revenue::numeric / total_sessions, 2)
FROM sessions
CROSS JOIN orders_summary

UNION ALL

SELECT
    'net_revenue_per_session',
    ROUND((gross_revenue - total_refund_amount)::numeric / total_sessions, 2)
FROM sessions
CROSS JOIN orders_summary
CROSS JOIN refunds

UNION ALL

SELECT
    'gross_margin',
    ROUND(gross_margin, 2)
FROM orders_summary

UNION ALL

SELECT
    'gross_margin_rate_pct',
    ROUND(gross_margin::numeric / gross_revenue * 100, 2)
FROM orders_summary

UNION ALL

SELECT
    'refund_share_of_revenue_pct',
    ROUND(total_refund_amount::numeric / gross_revenue * 100, 2)
FROM orders_summary
CROSS JOIN refunds

UNION ALL

SELECT
    'refund_order_rate_pct',
    ROUND(refunded_orders::numeric / total_orders * 100, 2)
FROM orders_summary
CROSS JOIN refunds;


-- ============================================================
-- 2. Monthly KPI trend
-- ============================================================
-- What this query calculates:
-- Monthly sessions, orders, conversion rate, gross revenue,
-- net revenue, AOV and revenue per session.
--
-- Why it matters:
-- Shows how the business developed over time.
-- This will be useful for Power BI trend charts.

WITH monthly_sessions AS (
    SELECT
        DATE_TRUNC('month', created_at)::date AS month,
        COUNT(*) AS sessions
    FROM website_sessions
    GROUP BY DATE_TRUNC('month', created_at)::date
),

monthly_orders AS (
    SELECT
        DATE_TRUNC('month', created_at)::date AS month,
        COUNT(*) AS orders,
        SUM(price_usd) AS gross_revenue,
        SUM(price_usd - cogs_usd) AS gross_margin
    FROM orders
    GROUP BY DATE_TRUNC('month', created_at)::date
),

monthly_refunds AS (
    SELECT
        DATE_TRUNC('month', created_at)::date AS month,
        COALESCE(SUM(refund_amount_usd), 0) AS refund_amount
    FROM order_item_refunds
    GROUP BY DATE_TRUNC('month', created_at)::date
)

SELECT
    ms.month,
    ms.sessions,
    COALESCE(mo.orders, 0) AS orders,
    ROUND(COALESCE(mo.orders, 0)::numeric / NULLIF(ms.sessions, 0) * 100, 2) AS conversion_rate_pct,
    ROUND(COALESCE(mo.gross_revenue, 0), 2) AS gross_revenue,
    ROUND(COALESCE(mr.refund_amount, 0), 2) AS refund_amount,
    ROUND(COALESCE(mo.gross_revenue, 0) - COALESCE(mr.refund_amount, 0), 2) AS net_revenue,
    ROUND(COALESCE(mo.gross_margin, 0), 2) AS gross_margin,
    ROUND(COALESCE(mo.gross_margin, 0)::numeric / NULLIF(COALESCE(mo.gross_revenue, 0), 0) * 100, 2) AS gross_margin_rate_pct,
    ROUND(COALESCE(mo.gross_revenue, 0)::numeric / NULLIF(COALESCE(mo.orders, 0), 0), 2) AS average_order_value,
    ROUND(COALESCE(mo.gross_revenue, 0)::numeric / NULLIF(ms.sessions, 0), 2) AS revenue_per_session
FROM monthly_sessions ms
LEFT JOIN monthly_orders mo
    ON ms.month = mo.month
LEFT JOIN monthly_refunds mr
    ON ms.month = mr.month
ORDER BY ms.month;

-- ============================================================
-- 3. Marketing source performance
-- ============================================================
-- What this query calculates:
-- Sessions, orders, conversion rate, revenue, AOV and revenue per session
-- by traffic source.
--
-- Why it matters:
-- Identifies which sources bring traffic, which sources convert,
-- and which sources generate valuable sessions.

SELECT
    COALESCE(ws.utm_source, 'direct_or_none') AS utm_source,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(COUNT(DISTINCT o.order_id)::numeric / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conversion_rate_pct,
    ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue,
    ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value,
    ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY COALESCE(ws.utm_source, 'direct_or_none')
ORDER BY gross_revenue DESC;

-- ============================================================
-- 5. Campaign performance
-- ============================================================
-- What this query calculates:
-- Sessions, orders, conversion rate, revenue and revenue per session
-- by UTM campaign.
--
-- Why it matters:
-- Helps compare marketing campaigns based on both volume and quality.

SELECT
    COALESCE(ws.utm_campaign, 'no_campaign') AS utm_campaign,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(COUNT(DISTINCT o.order_id)::numeric / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conversion_rate_pct,
    ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue,
    ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value,
    ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY COALESCE(ws.utm_campaign, 'no_campaign')
ORDER BY gross_revenue DESC;

-- ============================================================
-- 6. Device performance
-- ============================================================
-- What this query calculates:
-- Sessions, orders, conversion rate, revenue and revenue per session
-- by device type.
--
-- Why it matters:
-- Helps identify whether desktop or mobile traffic performs better.

SELECT
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(COUNT(DISTINCT o.order_id)::numeric / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS conversion_rate_pct,
    ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue,
    ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value,
    ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type
ORDER BY gross_revenue DESC;

-- ============================================================
-- 7. Product performance
-- ============================================================
-- What this query calculates:
-- Product-level revenue, margin, sold items, refund amount and refund rate.
--
-- Why it matters:
-- Product analysis should be done at order_items level,
-- because one order can contain multiple items.

SELECT
    p.product_id,
    p.product_name,
    COUNT(oi.order_item_id) AS items_sold,
    ROUND(SUM(oi.price_usd), 2) AS gross_revenue,
    ROUND(SUM(oi.cogs_usd), 2) AS total_cogs,
    ROUND(SUM(oi.price_usd - oi.cogs_usd), 2) AS gross_margin,
    ROUND(SUM(oi.price_usd - oi.cogs_usd)::numeric / NULLIF(SUM(oi.price_usd), 0) * 100, 2) AS gross_margin_rate_pct,
    COUNT(r.order_item_refund_id) AS refunded_items,
    ROUND(COALESCE(SUM(r.refund_amount_usd), 0), 2) AS refund_amount,
    ROUND(COUNT(r.order_item_refund_id)::numeric / NULLIF(COUNT(oi.order_item_id), 0) * 100, 2) AS item_refund_rate_pct,
    ROUND(SUM(oi.price_usd) - COALESCE(SUM(r.refund_amount_usd), 0), 2) AS net_revenue
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN order_item_refunds r
    ON oi.order_item_id = r.order_item_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY gross_revenue DESC;