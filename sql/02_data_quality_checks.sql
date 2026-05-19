-- ============================================================
-- 02_data_quality_checks.sql
-- Purpose:
-- Validate primary keys, foreign keys, relationship cardinality,
-- date logic and basic consistency before KPI analysis.
-- ============================================================


-- ============================================================
-- 1. Primary key uniqueness checks
-- ============================================================
-- What this query checks:
-- Checks whether primary keys are unique in each core table.
--
-- Why it matters:
-- Primary keys must be unique. Duplicates would break joins,
-- counts and KPI calculations.
--
-- Expected result:
-- duplicate_ids should be 0 for every table.

SELECT
    'orders' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_ids
FROM orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    COUNT(DISTINCT order_item_id),
    COUNT(*) - COUNT(DISTINCT order_item_id)
FROM order_items

UNION ALL

SELECT
    'order_item_refunds',
    COUNT(*),
    COUNT(DISTINCT order_item_refund_id),
    COUNT(*) - COUNT(DISTINCT order_item_refund_id)
FROM order_item_refunds

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM products

UNION ALL

SELECT
    'website_sessions',
    COUNT(*),
    COUNT(DISTINCT website_session_id),
    COUNT(*) - COUNT(DISTINCT website_session_id)
FROM website_sessions

UNION ALL

SELECT
    'website_pageviews',
    COUNT(*),
    COUNT(DISTINCT website_pageview_id),
    COUNT(*) - COUNT(DISTINCT website_pageview_id)
FROM website_pageviews;


-- Result:
-- duplicate_ids = 0 for all tables.
--
-- Interpretation:
-- All primary keys are unique.


-- ============================================================
-- 2. Primary key NULL checks
-- ============================================================
-- What this query checks:
-- Checks whether primary keys contain NULL values.
--
-- Why matters:
-- Primary keys must be unique and non-null.
--
-- Expected result:
-- null_count should be 0 for every primary key.

SELECT
    'orders.order_id' AS field_name,
    COUNT(*) AS null_count
FROM orders
WHERE order_id IS NULL

UNION ALL

SELECT
    'order_items.order_item_id',
    COUNT(*)
FROM order_items
WHERE order_item_id IS NULL

UNION ALL

SELECT
    'order_item_refunds.order_item_refund_id',
    COUNT(*)
FROM order_item_refunds
WHERE order_item_refund_id IS NULL

UNION ALL

SELECT
    'products.product_id',
    COUNT(*)
FROM products
WHERE product_id IS NULL

UNION ALL

SELECT
    'website_sessions.website_session_id',
    COUNT(*)
FROM website_sessions
WHERE website_session_id IS NULL

UNION ALL

SELECT
    'website_pageviews.website_pageview_id',
    COUNT(*)
FROM website_pageviews
WHERE website_pageview_id IS NULL;


-- Result:
-- null_count = 0 for all primary keys.
--
-- Interpretation:
-- No primary key contains NULL values.


-- ============================================================
-- 3. Foreign key integrity checks
-- ============================================================
-- What this query checks:
-- Checks whether child records have matching parent records.
--
-- Why it matters:
-- Broken relationships would make joins and KPI calculations unreliable.
--
-- Expected result:
-- orphan_count should be 0 for every check.

SELECT
    'orders_without_matching_session' AS check_name,
    COUNT(*) AS orphan_count
FROM orders o
LEFT JOIN website_sessions ws
    ON o.website_session_id = ws.website_session_id
WHERE ws.website_session_id IS NULL

UNION ALL

SELECT
    'order_items_without_matching_order',
    COUNT(*)
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'order_items_without_matching_product',
    COUNT(*)
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'order_item_refunds_without_matching_order_item',
    COUNT(*)
FROM order_item_refunds r
LEFT JOIN order_items oi
    ON r.order_item_id = oi.order_item_id
WHERE oi.order_item_id IS NULL

UNION ALL

SELECT
    'order_item_refunds_without_matching_order',
    COUNT(*)
FROM order_item_refunds r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'website_pageviews_without_matching_session',
    COUNT(*)
FROM website_pageviews wp
LEFT JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id
WHERE ws.website_session_id IS NULL

UNION ALL

SELECT
    'orders_without_matching_primary_product',
    COUNT(*)
FROM orders o
LEFT JOIN products p
    ON o.primary_product_id = p.product_id
WHERE p.product_id IS NULL;


-- Result:
-- orphan_count = 0 for all checked relationships.
--
-- Interpretation:
-- All tested foreign key relationships are valid.


-- ============================================================
-- 4. Relationship cardinality checks
-- ============================================================
-- What this section checks:
-- Checks how records relate to each other in terms of quantity.
--
-- Why it matters:
-- Cardinality affects conversion rate, funnel analysis,
-- product analysis and refund logic.


-- ------------------------------------------------------------
-- 4.1 Orders per session
-- ------------------------------------------------------------
-- What this query checks:
-- Checks how many orders can belong to one website session.
--
-- Why it matters:
-- If one session can have multiple orders, conversion rate logic
-- must count sessions with orders instead of raw orders.
--
-- Expected result:
-- max_orders_per_session = 1
-- sessions_with_multiple_orders = 0

WITH orders_per_session AS (
    SELECT
        website_session_id,
        COUNT(*) AS order_count
    FROM orders
    GROUP BY website_session_id
)

SELECT
    MAX(order_count) AS max_orders_per_session,
    COUNT(*) FILTER (WHERE order_count > 1) AS sessions_with_multiple_orders
FROM orders_per_session;


-- Result:
-- max_orders_per_session = 1
-- sessions_with_multiple_orders = 0
--
-- Interpretation:
-- One website session has at most one order.
-- Session-to-order conversion rate can be calculated as orders / sessions.


-- ------------------------------------------------------------
-- 4.2 Pageviews per session
-- ------------------------------------------------------------
-- What this query checks:
-- Checks how many pageviews belong to one website session.
--
-- Why it matters:
-- Pageview depth helps understand browsing behavior and prepares
-- the dataset for funnel analysis.
--
-- Expected result:
-- Each session should have at least one pageview.

WITH pageviews_per_session AS (
    SELECT
        website_session_id,
        COUNT(*) AS pageview_count
    FROM website_pageviews
    GROUP BY website_session_id
)

SELECT
    MIN(pageview_count) AS min_pageviews_per_session,
    ROUND(AVG(pageview_count), 2) AS avg_pageviews_per_session,
    MAX(pageview_count) AS max_pageviews_per_session
FROM pageviews_per_session;


-- Result:
-- min_pageviews_per_session = 1
-- avg_pageviews_per_session = 2.51
-- max_pageviews_per_session = 7
--
-- Interpretation:
-- Every session has at least one pageview.
-- Average browsing depth is around 2.5 pageviews per session.


-- ------------------------------------------------------------
-- 4.3 Items per order
-- ------------------------------------------------------------
-- What this query checks:
-- Checks how many order items belong to one order.
--
-- Why it matters:
-- Product-level analysis should use order_items, not only
-- orders.primary_product_id, because some orders contain multiple items.
--
-- Expected result:
-- min should be at least 1.

WITH items_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
)

SELECT
    MIN(item_count) AS min_items_per_order,
    ROUND(AVG(item_count), 2) AS avg_items_per_order,
    MAX(item_count) AS max_items_per_order
FROM items_per_order;


-- Result:
-- min_items_per_order = 1
-- avg_items_per_order = 1.24
-- max_items_per_order = 2
--
-- Interpretation:
-- Most orders contain one item, but some contain two.
-- Product performance analysis should be done at order_items level.


-- ------------------------------------------------------------
-- 4.4 Refunds per order item
-- ------------------------------------------------------------
-- What this query checks:
-- Checks whether one order item can have multiple refund records.
--
-- Why it matters:
-- Multiple refund records per item would require more careful
-- aggregation in refund analysis.
--
-- Expected result:
-- max_refunds_per_order_item = 1
-- order_items_with_multiple_refunds = 0

WITH refunds_per_item AS (
    SELECT
        order_item_id,
        COUNT(*) AS refund_count
    FROM order_item_refunds
    GROUP BY order_item_id
)

SELECT
    MAX(refund_count) AS max_refunds_per_order_item,
    COUNT(*) FILTER (WHERE refund_count > 1) AS order_items_with_multiple_refunds
FROM refunds_per_item;


-- Result:
-- max_refunds_per_order_item = 1
-- order_items_with_multiple_refunds = 0
--
-- Interpretation:
-- Each refunded order item has at most one refund record.
-- Refund logic is relatively simple.


-- ============================================================
-- 5. Date logic checks
-- ============================================================
-- What this section checks:
-- Checks whether timestamps follow a logical event order.
--
-- Why it matters:
-- Events should not happen before the event they depend on.


-- ------------------------------------------------------------
-- 5.1 Orders before session
-- ------------------------------------------------------------
-- Expected result:
-- orders_before_session_count = 0

SELECT
    COUNT(*) AS orders_before_session_count
FROM orders o
JOIN website_sessions ws
    ON o.website_session_id = ws.website_session_id
WHERE o.created_at < ws.created_at;


-- Result:
-- orders_before_session_count = 0
--
-- Interpretation:
-- No orders were created before their related website session.


-- ------------------------------------------------------------
-- 5.2 Pageviews before session
-- ------------------------------------------------------------
-- Expected result:
-- pageviews_before_session_count = 0

SELECT
    COUNT(*) AS pageviews_before_session_count
FROM website_pageviews wp
JOIN website_sessions ws
    ON wp.website_session_id = ws.website_session_id
WHERE wp.created_at < ws.created_at;


-- Result:
-- pageviews_before_session_count = 0
--
-- Interpretation:
-- No pageviews were created before their related website session.


-- ------------------------------------------------------------
-- 5.3 Refunds before order item
-- ------------------------------------------------------------
-- Expected result:
-- refunds_before_order_item_count = 0

SELECT
    COUNT(*) AS refunds_before_order_item_count
FROM order_item_refunds r
JOIN order_items oi
    ON r.order_item_id = oi.order_item_id
WHERE r.created_at < oi.created_at;


-- Result:
-- refunds_before_order_item_count = 0
--
-- Interpretation:
-- No refunds were created before their related order item.


-- ------------------------------------------------------------
-- 5.4 Refunds before order
-- ------------------------------------------------------------
-- Expected result:
-- refunds_before_order_count = 0

SELECT
    COUNT(*) AS refunds_before_order_count
FROM order_item_refunds r
JOIN orders o
    ON r.order_id = o.order_id
WHERE r.created_at < o.created_at;


-- Result:
-- refunds_before_order_count = 0
--
-- Interpretation:
-- No refunds were created before their related order.
