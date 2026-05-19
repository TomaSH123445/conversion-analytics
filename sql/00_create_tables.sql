-- 00_create_tables.sql
-- Purpose: Create PostgreSQL tables for the Maven Fuzzy Factory e-commerce dataset.
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    product_name VARCHAR(255)
);

CREATE TABLE website_sessions (
    website_session_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    user_id INT,
    is_repeat_session INT,
    utm_source VARCHAR(100),
    utm_campaign VARCHAR(100),
    utm_content VARCHAR(100),
    device_type VARCHAR(50),
    http_referer VARCHAR(255)
);

CREATE TABLE website_pageviews (
    website_pageview_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    website_session_id INT,
    pageview_url VARCHAR(255),
    CONSTRAINT fk_pageviews_sessions
        FOREIGN KEY (website_session_id)
        REFERENCES website_sessions(website_session_id)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    website_session_id INT,
    user_id INT,
    primary_product_id INT,
    items_purchased INT,
    price_usd NUMERIC(10,2),
    cogs_usd NUMERIC(10,2),
    CONSTRAINT fk_orders_sessions
        FOREIGN KEY (website_session_id)
        REFERENCES website_sessions(website_session_id),
    CONSTRAINT fk_orders_products
        FOREIGN KEY (primary_product_id)
        REFERENCES products(product_id)
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    order_id INT,
    product_id INT,
    is_primary_item INT,
    price_usd NUMERIC(10,2),
    cogs_usd NUMERIC(10,2),
    CONSTRAINT fk_order_items_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_products
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);

CREATE TABLE order_item_refunds (
    order_item_refund_id INT PRIMARY KEY,
    created_at TIMESTAMP,
    order_item_id INT,
    order_id INT,
    refund_amount_usd NUMERIC(10,2),
    CONSTRAINT fk_refunds_order_items
        FOREIGN KEY (order_item_id)
        REFERENCES order_items(order_item_id),
    CONSTRAINT fk_refunds_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
    );

