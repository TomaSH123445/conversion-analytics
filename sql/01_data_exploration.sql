-- ============================================================
-- 01_data_exploration.sql
-- Purpose:
-- Understand the dataset structure, row counts, date ranges,
-- main dimensions, products, traffic sources and basic website behavior.
--
-- Run order: 00_create_tables.sql -> import CSVs -> this file -> 02 -> 03 -> 04
-- ============================================================


-- ============================================================
-- 1. Row counts
-- ============================================================
-- What this query checks:
-- Shows the number of records in each core table.
--
-- Why it matters:
-- Helps verify that CSV import into PostgreSQL was successful.

SELECT 'products' AS table_name, COUNT(*) AS row_count FROM products
UNION ALL
SELECT 'website_sessions', COUNT(*) FROM website_sessions
UNION ALL
SELECT 'website_pageviews', COUNT(*) FROM website_pageviews
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_item_refunds', COUNT(*) FROM order_item_refunds;


-- Expected result:
-- products: 4
-- website_sessions: 472871
-- website_pageviews: 1188124
-- orders: 32313
-- order_items: 40025
-- order_item_refunds: 1731


-- ============================================================
-- 2. Date ranges
-- ============================================================
-- What this query checks:
-- Shows the first and last timestamp in each event table.
--
-- Why it matters:
-- Defines the time coverage of the dataset.

SELECT
    'website_sessions' AS table_name,
    MIN(created_at) AS min_date,
    MAX(created_at) AS max_date
FROM website_sessions

UNION ALL

SELECT
    'website_pageviews',
    MIN(created_at),
    MAX(created_at)
FROM website_pageviews

UNION ALL

SELECT
    'orders',
    MIN(created_at),
    MAX(created_at)
FROM orders

UNION ALL

SELECT
    'order_items',
    MIN(created_at),
    MAX(created_at)
FROM order_items

UNION ALL

SELECT
    'order_item_refunds',
    MIN(created_at),
    MAX(created_at)
FROM order_item_refunds

UNION ALL

SELECT
    'products',
    MIN(created_at),
    MAX(created_at)
FROM products;


-- ============================================================
-- 3. Products
-- ============================================================
-- What this query checks:
-- Shows all products in the product catalog.
--
-- Why it matters:
-- Products will be used for product performance and refund analysis.

SELECT
    product_id,
    created_at,
    product_name
FROM products
ORDER BY product_id;


-- ============================================================
-- 4. Sessions by UTM source
-- ============================================================
-- What this query checks:
-- Shows traffic volume by marketing/source origin.
--
-- Why it matters:
-- Helps understand which channels drive traffic.

SELECT
    COALESCE(utm_source, 'direct_or_none') AS utm_source,
    COUNT(*) AS sessions
FROM website_sessions
GROUP BY COALESCE(utm_source, 'direct_or_none')
ORDER BY sessions DESC;


-- ============================================================
-- 5. Sessions by UTM campaign
-- ============================================================
-- What this query checks:
-- Shows traffic volume by marketing campaign.
--
-- Why it matters:
-- Campaigns will later be used for marketing performance analysis.

SELECT
    COALESCE(utm_campaign, 'no_campaign') AS utm_campaign,
    COUNT(*) AS sessions
FROM website_sessions
GROUP BY COALESCE(utm_campaign, 'no_campaign')
ORDER BY sessions DESC;


-- ============================================================
-- 6. Sessions by UTM content
-- ============================================================
-- What this query checks:
-- Shows traffic volume by ad/content variant.
--
-- Why it matters:
-- Useful for ad/content performance analysis.

SELECT
    COALESCE(utm_content, 'no_content') AS utm_content,
    COUNT(*) AS sessions
FROM website_sessions
GROUP BY COALESCE(utm_content, 'no_content')
ORDER BY sessions DESC;


-- ============================================================
-- 7. Sessions by device type
-- ============================================================
-- What this query checks:
-- Shows traffic distribution by device.
--
-- Why it matters:
-- Device type can strongly affect conversion performance.

SELECT
    device_type,
    COUNT(*) AS sessions
FROM website_sessions
GROUP BY device_type
ORDER BY sessions DESC;


-- ============================================================
-- 8. Most common pageview URLs
-- ============================================================
-- What this query checks:
-- Shows the most visited pages.
--
-- Why it matters:
-- Helps prepare future funnel analysis.

SELECT
    pageview_url,
    COUNT(*) AS pageviews,
    COUNT(DISTINCT website_session_id) AS sessions_reached
FROM website_pageviews
GROUP BY pageview_url
ORDER BY pageviews DESC;


-- ============================================================
-- 9. Landing pages
-- ============================================================
-- What this query checks:
-- Identifies the first pageview in each session.
--
-- Why it matters:
-- Landing pages will be important for conversion and funnel analysis.

WITH first_pageview AS (
    SELECT
        website_session_id,
        MIN(website_pageview_id) AS first_pageview_id
    FROM website_pageviews
    GROUP BY website_session_id
)

SELECT
    wp.pageview_url AS landing_page,
    COUNT(*) AS sessions
FROM first_pageview fp
JOIN website_pageviews wp
    ON fp.first_pageview_id = wp.website_pageview_id
GROUP BY wp.pageview_url
ORDER BY sessions DESC;