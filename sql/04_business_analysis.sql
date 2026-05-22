-- ============================================================
-- Purpose:
-- Answer key business questions using validated KPI logic.
-- This file focuses on interpretation, comparison and decision support.
-- ============================================================


-- ============================================================
-- 1. Monthly business performance
-- ============================================================
-- Business question:
-- Is business growth driven by traffic volume, conversion rate,
-- average order value, or revenue per session?
--
-- Analysis logic:
-- Aggregate sessions and orders by month.
-- Then calculate conversion rate, gross revenue, AOV and revenue per session.
--
-- Business use:
-- Helps understand whether growth comes from acquisition,
-- website conversion efficiency or order value.

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
        SUM(price_usd) AS gross_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', created_at)::date
),

monthly_base AS (
    SELECT
        ms.month,
        ms.sessions,
        COALESCE(mo.orders, 0) AS orders,
        ROUND(COALESCE(mo.orders, 0)::numeric / NULLIF(ms.sessions, 0) * 100, 2) AS conversion_rate_pct,
        ROUND(COALESCE(mo.gross_revenue, 0), 2) AS gross_revenue,
        ROUND(COALESCE(mo.gross_revenue, 0)::numeric / NULLIF(COALESCE(mo.orders, 0), 0), 2) AS average_order_value,
        ROUND(COALESCE(mo.gross_revenue, 0)::numeric / NULLIF(ms.sessions, 0), 2) AS revenue_per_session
    FROM monthly_sessions ms
    LEFT JOIN monthly_orders mo
        ON ms.month = mo.month
),

monthly_with_lag AS (
    SELECT
        month,
        sessions,
        orders,
        conversion_rate_pct,
        gross_revenue,
        average_order_value,
        revenue_per_session,
        LAG(sessions) OVER (ORDER BY month) AS previous_month_sessions,
        LAG(orders) OVER (ORDER BY month) AS previous_month_orders,
        LAG(gross_revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly_base
)

SELECT
    month,
    sessions,
    orders,
    conversion_rate_pct,
    gross_revenue,
    average_order_value,
    revenue_per_session,

    ROUND((sessions - previous_month_sessions)::numeric / NULLIF(previous_month_sessions, 0) * 100, 2) AS sessions_mom_change_pct,
    ROUND((orders - previous_month_orders)::numeric / NULLIF(previous_month_orders, 0) * 100, 2) AS orders_mom_change_pct,
    ROUND((gross_revenue - previous_month_revenue)::numeric / NULLIF(previous_month_revenue, 0) * 100, 2) AS revenue_mom_change_pct
FROM monthly_with_lag
ORDER BY month;


-- ============================================================
-- 2. Marketing source + campaign performance
-- ============================================================
-- Business question:
-- Which source and campaign combinations bring the most valuable traffic?
--
-- Analysis logic:
-- Use website_sessions as the base table and LEFT JOIN orders.
-- Group by utm_source + utm_campaign.
-- Compare volume metrics and efficiency metrics.
--
-- Business use:
-- Helps identify which acquisition channels and campaigns should be scaled,
-- optimized or investigated further.
--
-- Important:
-- LEFT JOIN is required because non-converting sessions must stay in the denominator.

WITH overall AS (
    SELECT
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COALESCE(SUM(o.price_usd), 0) AS total_revenue,
        ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2) AS overall_conversion_rate_pct,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0), 2) AS overall_revenue_per_session
    FROM website_sessions ws
    LEFT JOIN orders o
        ON ws.website_session_id = o.website_session_id
),

source_campaign AS (
    SELECT
        COALESCE(ws.utm_source, 'direct_or_none') AS utm_source,
        COALESCE(ws.utm_campaign, 'no_campaign') AS utm_campaign,
        COUNT(DISTINCT ws.website_session_id) AS sessions,
        COUNT(DISTINCT o.order_id) AS orders,
        ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2) AS conversion_rate_pct,
        ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0), 2) AS revenue_per_session
    FROM website_sessions ws
    LEFT JOIN orders o
        ON ws.website_session_id = o.website_session_id
    GROUP BY
        COALESCE(ws.utm_source, 'direct_or_none'),
        COALESCE(ws.utm_campaign, 'no_campaign')
    HAVING COUNT(DISTINCT ws.website_session_id) >= 1000
)

SELECT
    sc.utm_source,
    sc.utm_campaign,
    sc.sessions,
    sc.orders,
    sc.conversion_rate_pct,
    sc.gross_revenue,
    sc.average_order_value,
    sc.revenue_per_session,
    ROUND(sc.sessions::numeric / overall.total_sessions * 100, 2) AS session_share_pct,

    CASE
        WHEN sc.conversion_rate_pct >= overall.overall_conversion_rate_pct
             AND sc.revenue_per_session >= overall.overall_revenue_per_session
            THEN 'high_quality_traffic'
        WHEN sc.sessions >= overall.total_sessions * 0.10
             AND sc.revenue_per_session < overall.overall_revenue_per_session
            THEN 'high_volume_lower_efficiency'
        WHEN sc.sessions < overall.total_sessions * 0.10
             AND sc.revenue_per_session >= overall.overall_revenue_per_session
            THEN 'smaller_but_high_value'
        ELSE 'average_or_low_priority'
    END AS business_segment
FROM source_campaign sc
CROSS JOIN overall
ORDER BY sc.revenue_per_session DESC;

-- high_quality_traffic = strong candidate for scaling
-- high_volume_lower_efficiency = large channel, but needs optimization
-- smaller_but_high_value = possible opportunity if scalable
-- average_or_low_priority = lower priority unless strategically important



-- ============================================================
-- 3. Device opportunity analysis
-- ============================================================
-- Business question:
-- Is desktop or mobile underperforming?
--
-- Analysis logic:
-- Compare device performance against overall conversion rate
-- and overall revenue per session.
--
-- Business use:
-- Helps identify UX, checkout or traffic quality issues by device.

WITH overall AS (
    SELECT
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COALESCE(SUM(o.price_usd), 0) AS total_revenue,
        ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2) AS overall_conversion_rate_pct,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0), 2) AS overall_revenue_per_session
    FROM website_sessions ws
    LEFT JOIN orders o
        ON ws.website_session_id = o.website_session_id
),

device_performance AS (
    SELECT
        ws.device_type,
        COUNT(DISTINCT ws.website_session_id) AS sessions,
        COUNT(DISTINCT o.order_id) AS orders,
        ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2) AS conversion_rate_pct,
        ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0), 2) AS revenue_per_session
    FROM website_sessions ws
    LEFT JOIN orders o
        ON ws.website_session_id = o.website_session_id
    GROUP BY ws.device_type
)

SELECT
    dp.device_type,
    dp.sessions,
    ROUND(dp.sessions::numeric / overall.total_sessions * 100, 2) AS session_share_pct,
    dp.orders,
    dp.conversion_rate_pct,
    overall.overall_conversion_rate_pct,
    ROUND(dp.conversion_rate_pct - overall.overall_conversion_rate_pct, 2) AS conversion_rate_gap_pp,
    dp.gross_revenue,
    dp.revenue_per_session,
    overall.overall_revenue_per_session,
    ROUND(dp.revenue_per_session - overall.overall_revenue_per_session, 2) AS revenue_per_session_gap,

    CASE
        WHEN dp.sessions >= overall.total_sessions * 0.30
             AND dp.conversion_rate_pct < overall.overall_conversion_rate_pct
            THEN 'high_volume_underperforming_device'
        WHEN dp.conversion_rate_pct >= overall.overall_conversion_rate_pct
             AND dp.revenue_per_session >= overall.overall_revenue_per_session
            THEN 'strong_device_segment'
        ELSE 'monitor'
    END AS device_opportunity
FROM device_performance dp
CROSS JOIN overall
ORDER BY dp.sessions DESC;

-- ============================================================
-- 4. Product performance and refund risk
-- ============================================================
-- Business question:
-- Which products generate value, and which products create refund risk?
--
-- Analysis logic:
-- Use order_items as the base table because product analysis must be item-level.
-- LEFT JOIN refunds because most items are not refunded.
--
-- Business use:
-- Helps identify best products, margin drivers and products with refund problems.

WITH product_performance AS (
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
),

overall AS (
    SELECT
        ROUND(COUNT(r.order_item_refund_id)::numeric / NULLIF(COUNT(oi.order_item_id), 0) * 100, 2) AS overall_item_refund_rate_pct
    FROM order_items oi
    LEFT JOIN order_item_refunds r
        ON oi.order_item_id = r.order_item_id
)

SELECT
    pp.product_id,
    pp.product_name,
    pp.items_sold,
    pp.gross_revenue,
    pp.gross_margin,
    pp.gross_margin_rate_pct,
    pp.refunded_items,
    pp.refund_amount,
    pp.item_refund_rate_pct,
    overall.overall_item_refund_rate_pct,
    pp.net_revenue,

    RANK() OVER (ORDER BY pp.net_revenue DESC) AS net_revenue_rank,
    RANK() OVER (ORDER BY pp.item_refund_rate_pct DESC) AS refund_rate_rank,

    CASE
        WHEN pp.item_refund_rate_pct > overall.overall_item_refund_rate_pct
             AND pp.refunded_items >= 10
            THEN 'refund_risk'
        WHEN pp.net_revenue = MAX(pp.net_revenue) OVER ()
            THEN 'top_net_revenue_product'
        WHEN pp.gross_margin_rate_pct >= 60
            THEN 'strong_margin_product'
        ELSE 'standard_product'
    END AS product_business_status
FROM product_performance pp
CROSS JOIN overall
ORDER BY pp.net_revenue DESC;

-- Top net revenue product = main value driver
-- High refund rate product = possible quality or expectation issue
-- Strong margin product = good candidate for promotion if demand exists
-- Do not judge products only by gross revenue.



-- ============================================================
-- 5. Landing page performance
-- ============================================================
-- Business question:
-- Which landing pages bring traffic, and which landing pages convert?
--
-- Analysis logic:
-- Identify the first pageview in each session.
-- Then join landing page sessions to orders.
--
-- Business use:
-- Helps evaluate entry points and conversion opportunities.

WITH first_pageview AS (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
),

landing_pages AS (
    SELECT
        fp.website_session_id,
        wp.pageview_url AS landing_page
    FROM first_pageview fp
    JOIN website_pageviews wp
        ON fp.first_pageview_id = wp.website_pageview_id
),

overall AS (
    SELECT
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2) AS overall_conversion_rate_pct,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT ws.website_session_id), 0), 2) AS overall_revenue_per_session
    FROM website_sessions ws
    LEFT JOIN orders o
        ON ws.website_session_id = o.website_session_id
),

landing_performance AS (
    SELECT
        lp.landing_page,
        COUNT(DISTINCT lp.website_session_id) AS sessions,
        COUNT(DISTINCT o.order_id) AS orders,
        ROUND(COUNT(DISTINCT o.order_id)::numeric / NULLIF(COUNT(DISTINCT lp.website_session_id), 0) * 100, 2) AS conversion_rate_pct,
        ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue,
        ROUND(COALESCE(SUM(o.price_usd), 0)::numeric / NULLIF(COUNT(DISTINCT lp.website_session_id), 0), 2) AS revenue_per_session
    FROM landing_pages lp
    LEFT JOIN orders o
        ON lp.website_session_id = o.website_session_id
    GROUP BY lp.landing_page
    HAVING COUNT(DISTINCT lp.website_session_id) >= 1000
)

SELECT
    lp.landing_page,
    lp.sessions,
    ROUND(lp.sessions::numeric / overall.total_sessions * 100, 2) AS session_share_pct,
    lp.orders,
    lp.conversion_rate_pct,
    overall.overall_conversion_rate_pct,
    ROUND(lp.conversion_rate_pct - overall.overall_conversion_rate_pct, 2) AS conversion_rate_gap_pp,
    lp.gross_revenue,
    lp.revenue_per_session,
    overall.overall_revenue_per_session,
    ROUND(lp.revenue_per_session - overall.overall_revenue_per_session, 2) AS revenue_per_session_gap,

    CASE
        WHEN lp.sessions >= overall.total_sessions * 0.10
             AND lp.conversion_rate_pct < overall.overall_conversion_rate_pct
            THEN 'high_traffic_underperforming_landing_page'
        WHEN lp.conversion_rate_pct >= overall.overall_conversion_rate_pct
             AND lp.revenue_per_session >= overall.overall_revenue_per_session
            THEN 'strong_landing_page'
        ELSE 'monitor'
    END AS landing_page_status
FROM landing_performance lp
CROSS JOIN overall
ORDER BY lp.sessions DESC;

-- High traffic + weak conversion = CRO opportunity
-- High conversion + lower traffic = possible scaling opportunity
-- Strong landing page = can be benchmark for weaker pages



-- ============================================================
-- 6. Funnel step performance
-- ============================================================
-- Business question:
-- Where do users drop off in the website funnel?
--
-- Analysis logic:
-- Convert pageviews into session-level flags.
-- Count how many sessions reached each funnel step.
--
-- Business use:
-- Helps identify where users leave before purchase.
--
-- Important:
-- Check available pageview_url values in 01_data_exploration.sql.
-- If page URLs differ, adjust the IN lists below.
-- Lander URLs (/home, /lander-*) are not a separate funnel step in this query;
-- add a session flag and UNION row in funnel_counts if you need that step.

WITH session_flags AS (
    SELECT
        website_session_id,

        MAX(CASE
            WHEN pageview_url = '/products'
                THEN 1 ELSE 0
        END) AS reached_products,

        MAX(CASE
            WHEN pageview_url IN (
                '/the-original-mr-fuzzy',
                '/the-forever-love-bear',
                '/the-birthday-sugar-panda',
                '/the-hudson-river-mini-bear'
            )
                THEN 1 ELSE 0
        END) AS reached_product_detail,

        MAX(CASE
            WHEN pageview_url = '/cart'
                THEN 1 ELSE 0
        END) AS reached_cart,

        MAX(CASE
            WHEN pageview_url = '/shipping'
                THEN 1 ELSE 0
        END) AS reached_shipping,

        MAX(CASE
            WHEN pageview_url IN ('/billing', '/billing-2')
                THEN 1 ELSE 0
        END) AS reached_billing,

        MAX(CASE
            WHEN pageview_url = '/thank-you-for-your-order'
                THEN 1 ELSE 0
        END) AS reached_thank_you
    FROM website_pageviews
    GROUP BY website_session_id
),

funnel_counts AS (
    SELECT
        1 AS funnel_step_order,
        'session_started' AS funnel_step,
        COUNT(*) AS sessions_reached
    FROM session_flags

    UNION ALL

    SELECT
        2,
        'reached_products',
        SUM(reached_products)
    FROM session_flags

    UNION ALL

    SELECT
        3,
        'reached_product_detail',
        SUM(reached_product_detail)
    FROM session_flags

    UNION ALL

    SELECT
        4,
        'reached_cart',
        SUM(reached_cart)
    FROM session_flags

    UNION ALL

    SELECT
        5,
        'reached_shipping',
        SUM(reached_shipping)
    FROM session_flags

    UNION ALL

    SELECT
        6,
        'reached_billing',
        SUM(reached_billing)
    FROM session_flags

    UNION ALL

    SELECT
        7,
        'completed_order',
        SUM(reached_thank_you)
    FROM session_flags
),

funnel_with_context AS (
    SELECT
        funnel_step_order,
        funnel_step,
        sessions_reached,
        FIRST_VALUE(sessions_reached) OVER (ORDER BY funnel_step_order) AS total_sessions,
        LAG(sessions_reached) OVER (ORDER BY funnel_step_order) AS previous_step_sessions
    FROM funnel_counts
)

SELECT
    funnel_step_order,
    funnel_step,
    sessions_reached,

    ROUND(sessions_reached::numeric / NULLIF(total_sessions, 0) * 100, 2) AS conversion_from_total_pct,

    ROUND(
        sessions_reached::numeric / NULLIF(previous_step_sessions, 0) * 100,
        2
    ) AS conversion_from_previous_step_pct,

    previous_step_sessions - sessions_reached AS dropoff_from_previous_step,

    ROUND(
        (previous_step_sessions - sessions_reached)::numeric / NULLIF(previous_step_sessions, 0) * 100,
        2
    ) AS dropoff_from_previous_step_pct
FROM funnel_with_context
ORDER BY funnel_step_order;

-- The largest dropoff_from_previous_step_pct shows the biggest funnel leak.
-- If many users reach product detail but few reach cart, product page/cart intent may be weak.
-- If many reach billing but few complete order, checkout friction may be the issue.
-- This section is one of the strongest parts of the project for e-commerce analytics.

