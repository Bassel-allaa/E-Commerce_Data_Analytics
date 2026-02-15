-- Data cleaning queries for the e-commerce dataset

ALTER TABLE orders
ALTER COLUMN order_estimated_delivery_date TYPE DATE USING order_estimated_delivery_date::DATE;

ALTER TABLE order_reviews
ALTER COLUMN review_creation_date TYPE DATE USING review_creation_date::DATE;


--Check for NULL values in key columns
SELECT 
    'orders' AS table_name,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_status,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS null_purchase_date,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer
FROM orders
UNION ALL
SELECT 
    'order_items',
    COUNT(*) FILTER (WHERE price IS NULL),
    COUNT(*) FILTER (WHERE freight_value IS NULL),
    COUNT(*) FILTER (WHERE product_id IS NULL)
FROM order_items
UNION ALL
SELECT 
    'order_reviews',
    COUNT(*) FILTER (WHERE review_score IS NULL),
    NULL,
    NULL
FROM order_reviews;



-- Find duplicate customers
SELECT customer_id, COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1; -- No Data

-- Find duplicate products
SELECT product_id, COUNT(*)
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1; -- No Data



-- Trim whitespace and convert to uppercase for state codes
UPDATE customers
SET customer_state = UPPER(TRIM(customer_state));

UPDATE sellers
SET seller_state = UPPER(TRIM(seller_state));

-- Trim and clean city names
UPDATE customers
SET customer_city = TRIM(customer_city);

UPDATE sellers
SET seller_city = TRIM(seller_city);


-- Check for invalid review scores
SELECT review_score, COUNT(*)
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5
   OR review_score IS NULL
GROUP BY review_score -- No invalid scores found

-- Find invalid prices
SELECT 
    COUNT(*) FILTER (WHERE price <= 0) AS invalid_prices,
    COUNT(*) FILTER (WHERE freight_value < 0) AS invalid_freight,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight
FROM order_items; -- No invalid prices, but some freight values are 0 which may be valid for free shipping

-- Find orders with illogical date sequences
SELECT 
    order_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders
WHERE 
    -- Approved date before purchase
    (order_approved_at < order_purchase_timestamp)
    -- Delivered to carrier before purchase
    OR (order_delivered_carrier_date < order_purchase_timestamp)
    -- Delivered to customer before carrier pickup
    OR (order_delivered_customer_date < order_delivered_carrier_date)
    -- Delivered before approved
    OR (order_delivered_customer_date < order_approved_at); -- No illogical date sequences found


-- Check ZIP code lengths
SELECT 
    LENGTH(customer_zip_code_prefix) AS zip_length,
    COUNT(*) AS count
FROM customers
GROUP BY zip_length;

-- Pad ZIP codes to 5 digits if needed
UPDATE customers
SET customer_zip_code_prefix = LPAD(customer_zip_code_prefix, 5, '0')
WHERE LENGTH(customer_zip_code_prefix) < 5;

UPDATE sellers
SET seller_zip_code_prefix = LPAD(seller_zip_code_prefix, 5, '0')
WHERE LENGTH(seller_zip_code_prefix) < 5; -- No further issues found with ZIP codes after padding.

-- Check order status distribution
SELECT 
    order_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM orders
GROUP BY order_status
ORDER BY count DESC;


-- Find order_items without matching orders
SELECT COUNT(*)
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL; -- No orphan order_items found

-- Find order_items without matching products
SELECT COUNT(*)
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL; -- No orphan order_items found

-- Add total order value column to order_items
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS total_price DECIMAL(10, 2);

UPDATE order_items
SET total_price = price + freight_value;


-- Add delivery delay column to orders
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_delay_days INTEGER;
UPDATE orders
SET delivery_delay_days = EXTRACT(DAY FROM (order_delivered_customer_date - order_estimated_delivery_date))
WHERE order_delivered_customer_date IS NOT NULL 
  AND order_estimated_delivery_date IS NOT NULL;


-- Add on_time_delivery flag
ALTER TABLE orders ADD COLUMN IF NOT EXISTS on_time_delivery BOOLEAN;

UPDATE orders
SET on_time_delivery = (order_delivered_customer_date <= order_estimated_delivery_date)
WHERE order_delivered_customer_date IS NOT NULL 
  AND order_estimated_delivery_date IS NOT NULL;



-- Data Quality Report for key metrics
SELECT 
    'Total Orders' AS metric,
    COUNT(*)::TEXT AS value
FROM orders
UNION ALL
SELECT 'Orders with NULL customer_id', COUNT(*)::TEXT
FROM orders WHERE customer_id IS NULL
UNION ALL
SELECT 'Orders delivered', COUNT(*)::TEXT
FROM orders WHERE order_status = 'delivered'
UNION ALL
SELECT 'Orders cancelled', COUNT(*)::TEXT
FROM orders WHERE order_status = 'canceled'
UNION ALL
SELECT 'Total Customers', COUNT(DISTINCT customer_id)::TEXT
FROM customers
UNION ALL
SELECT 'Repeat Customers', COUNT(*)::TEXT
FROM (
    SELECT customer_unique_id
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
) sub
UNION ALL
SELECT 'Total Products', COUNT(*)::TEXT
FROM products
UNION ALL
SELECT 'Products with NULL category', COUNT(*)::TEXT
FROM products WHERE product_category_name IS NULL
UNION ALL
SELECT 'Total Reviews', COUNT(*)::TEXT
FROM order_reviews
UNION ALL
SELECT 'Reviews with NULL score', COUNT(*)::TEXT
FROM order_reviews WHERE review_score IS NULL;


CREATE OR REPLACE VIEW products_with_english_categories AS
SELECT 
    p.product_id,
    p.product_category_name AS product_category_name_portuguese,
    COALESCE(t.product_category_name_english, p.product_category_name, 'Uncategorized') AS product_category_name_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM products p
LEFT JOIN product_category_name_translation t 
    ON p.product_category_name = t.product_category_name

SELECT *
FROM products_with_english_categories


-- Checking if the column has NULLs
SELECT count(*) 
FROM order_reviews
WHERE review_comment_message IS NULL; -- Found 58247 NULL values in review_comment_message

-- Updating the NULL values to a default string
UPDATE order_reviews
SET review_comment_message = 'No Review Provided'
WHERE review_comment_message IS NULL;


-- Create deduplicated geolocation table
CREATE TABLE geolocation_clean AS
SELECT DISTINCT ON (geolocation_zip_code_prefix)
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM geolocation
ORDER BY geolocation_zip_code_prefix;

-- Add primary key
ALTER TABLE geolocation_clean 
ADD PRIMARY KEY (geolocation_zip_code_prefix);

-- Create index for faster joins
CREATE INDEX idx_geolocation_clean_zip ON geolocation_clean(geolocation_zip_code_prefix);


-- Compare original vs clean geolocation
SELECT 
    'Original' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zipcodes
FROM geolocation
UNION ALL
SELECT 
    'Clean',
    COUNT(*),
    COUNT(DISTINCT geolocation_zip_code_prefix)
FROM geolocation_clean;