CREATE TABLE dim_date AS -- Creating a date dimension table for Power BI optimization
SELECT DISTINCT
    DATE(orders.order_purchase_timestamp) AS date,
    EXTRACT(YEAR FROM orders.order_purchase_timestamp) AS year,
    EXTRACT(MONTH FROM orders.order_purchase_timestamp) AS month,
    EXTRACT(DAY FROM orders.order_purchase_timestamp) AS day,
    EXTRACT(QUARTER FROM orders.order_purchase_timestamp) AS quarter,
    TO_CHAR(orders.order_purchase_timestamp, 'Month') AS month_name,
    TO_CHAR(orders.order_purchase_timestamp, 'Day') AS day_name,
    EXTRACT(DOW FROM orders.order_purchase_timestamp) AS day_of_week,
    EXTRACT(WEEK FROM orders.order_purchase_timestamp) AS week_of_year
FROM 
    orders
WHERE 
    orders.order_purchase_timestamp IS NOT NULL
ORDER BY 
    date;

-- Adding Primary Key to Date Dimension
ALTER TABLE dim_date ADD PRIMARY KEY (date);

-- Creating Fact Orders Table for Centralized Order Metrics
CREATE TABLE fact_orders AS
SELECT 
    orders.order_id,
    orders.customer_id,
    orders.order_status,
    orders.order_purchase_timestamp::DATE AS order_date,
    orders.order_delivered_customer_date::DATE AS delivery_date,
    orders.order_estimated_delivery_date::DATE AS estimated_delivery_date,
    orders.delivery_delay_days,
    orders.on_time_delivery,
    SUM(order_items.price) AS total_product_value,
    SUM(order_items.freight_value) AS total_freight_value,
    SUM(order_items.price + order_items.freight_value) AS total_order_value,
    COUNT(order_items.order_item_id) AS total_items,
    AVG(order_reviews.review_score) AS avg_review_score
FROM 
    orders
LEFT JOIN 
    order_items ON orders.order_id = order_items.order_id
LEFT JOIN 
    order_reviews ON orders.order_id = order_reviews.order_id
GROUP BY 
    orders.order_id,
    orders.customer_id,
    orders.order_status,
    orders.order_purchase_timestamp,
    orders.order_delivered_customer_date,
    orders.order_estimated_delivery_date,
    orders.delivery_delay_days,
    orders.on_time_delivery;

-- Adding Primary Key to Fact Orders Table
ALTER TABLE fact_orders ADD PRIMARY KEY (order_id);

-- Create indexes for common joins
CREATE INDEX idx_fact_orders_customer ON fact_orders(customer_id);
CREATE INDEX idx_fact_orders_date ON fact_orders(order_date);


-- Replace NULL order statuses (if any)
UPDATE products
SET product_category_name = 'Unknown'
WHERE product_category_name IS NULL;

-- Replace NULL order statuses (if any)
UPDATE orders
SET order_status = 'Unknown'
WHERE order_status IS NULL;

-- Replace NULL payment types (if any)
UPDATE order_payments
SET payment_type = 'Unknown'
WHERE payment_type IS NULL;

-- Replace NULL customer states
UPDATE customers
SET customer_state = 'NA'
WHERE customer_state IS NULL;

-- Replace NULL seller states
UPDATE sellers
SET seller_state = 'NA'
WHERE seller_state IS NULL

-- Data readiness check for Power BI
SELECT 
    'order_reviews - NULL titles' AS check_name,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) = 0 THEN '✓ PASS' ELSE '✗ FAIL' END AS status
FROM order_reviews 
WHERE review_comment_title IS NULL

UNION ALL

SELECT 
    'order_reviews - NULL messages',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM order_reviews 
WHERE review_comment_message IS NULL

UNION ALL

SELECT 
    'geolocation_clean - duplicate ZIPs',
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix),
    CASE WHEN COUNT(*) = COUNT(DISTINCT geolocation_zip_code_prefix) THEN '✓ PASS' ELSE '✗ FAIL' END
FROM geolocation_clean

UNION ALL

SELECT 
    'products - NULL categories',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM products 
WHERE product_category_name IS NULL

UNION ALL

SELECT 
    'orders - NULL status',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM orders 
WHERE order_status IS NULL

UNION ALL

SELECT 
    'dim_date - table exists',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM dim_date

UNION ALL

SELECT 
    'fact_orders - table exists',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN '✓ PASS' ELSE '✗ FAIL' END
FROM fact_orders;