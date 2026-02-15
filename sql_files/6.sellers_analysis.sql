/*
Questions to answer:
- Which sellers are top performers by revenue and customer satisfaction?
- What's the relationship between seller location and delivery times?
- How do seller ratings correlate with order values and customer reviews?
*/

-- Top Sellers by Revenue and Review Scores

SELECT
    order_items.seller_id,
    COUNT(DISTINCT order_items.order_id) AS total_orders,
    COUNT(DISTINCT order_items.product_id) AS unique_products_sold,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value,
    ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score,
    COUNT(order_reviews.review_id) AS total_reviews,
    SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) AS positive_reviews,
    SUM(CASE WHEN order_reviews.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews,
    ROUND(SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(order_reviews.review_id), 0), 2) AS positive_review_percentage
FROM
    order_items
JOIN orders USING (order_id)
LEFT JOIN order_reviews USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    order_items.seller_id
HAVING
    COUNT(DISTINCT order_items.order_id) >= 10  -- Filter for sellers with at least 10 orders
ORDER BY
    total_revenue DESC
LIMIT 20;


-- Seller Ratings Correlation with Sales Performance

WITH seller_performance AS (
    SELECT
        order_items.seller_id,
        SUM(order_items.price + order_items.freight_value) AS total_revenue,
        COUNT(DISTINCT order_items.order_id) AS total_orders,
        ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score,
        COUNT(order_reviews.review_id) AS total_reviews
    FROM
        order_items
    JOIN orders USING (order_id)
    LEFT JOIN order_reviews USING (order_id)
    WHERE
        orders.order_status = 'delivered'
    GROUP BY
        order_items.seller_id
    HAVING
        COUNT(order_reviews.review_id) >= 5  -- At least 5 reviews for reliable scoring
)
SELECT
    CASE
        WHEN avg_review_score >= 4.5 THEN 'Excellent (4.5-5.0)'
        WHEN avg_review_score >= 4.0 THEN 'Good (4.0-4.49)'
        WHEN avg_review_score >= 3.0 THEN 'Average (3.0-3.99)'
        WHEN avg_review_score >= 2.0 THEN 'Below Average (2.0-2.99)'
        ELSE 'Poor (< 2.0)'
    END AS review_category,
    COUNT(seller_id) AS number_of_sellers,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_seller,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_seller,
    SUM(total_revenue) AS total_category_revenue,
    SUM(total_orders) AS total_category_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score_in_category
FROM
    seller_performance
GROUP BY
    review_category
ORDER BY
    avg_review_score_in_category DESC;


-- Seller Location and Delivery Times Relationship

WITH seller_delivery_performance AS (
    SELECT
        sellers.seller_id,
        sellers.seller_city,
        sellers.seller_state,
        COUNT(DISTINCT orders.order_id) AS total_orders,
        ROUND(AVG(EXTRACT(EPOCH FROM (orders.order_delivered_customer_date - orders.order_purchase_timestamp)) / 86400), 2) AS avg_delivery_days,
        ROUND(AVG(EXTRACT(EPOCH FROM (orders.order_estimated_delivery_date - orders.order_purchase_timestamp)) / 86400), 2) AS avg_estimated_delivery_days,
        SUM(CASE WHEN orders.order_delivered_customer_date <= orders.order_estimated_delivery_date THEN 1 ELSE 0 END) AS on_time_deliveries,
        SUM(CASE WHEN orders.order_delivered_customer_date > orders.order_estimated_delivery_date THEN 1 ELSE 0 END) AS delayed_deliveries,
        ROUND(SUM(CASE WHEN orders.order_delivered_customer_date <= orders.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT orders.order_id), 2) AS on_time_percentage
    FROM
        sellers
    JOIN order_items USING (seller_id)
    JOIN orders USING (order_id)
    WHERE
        orders.order_status = 'delivered'
        AND orders.order_delivered_customer_date IS NOT NULL
        AND orders.order_estimated_delivery_date IS NOT NULL
    GROUP BY
        sellers.seller_id,
        sellers.seller_city,
        sellers.seller_state
    HAVING
        COUNT(DISTINCT orders.order_id) >= 10  -- At least 10 orders for statistical relevance
)
SELECT
    seller_state,
    COUNT(seller_id) AS number_of_sellers,
    SUM(total_orders) AS total_orders_from_state,
    ROUND(AVG(avg_delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(avg_estimated_delivery_days), 2) AS avg_estimated_days,
    SUM(on_time_deliveries) AS total_on_time_deliveries,
    SUM(delayed_deliveries) AS total_delayed_deliveries
FROM
    seller_delivery_performance
GROUP BY
    seller_state
HAVING
    COUNT(seller_id) >= 5  -- States with at least 5 sellers
ORDER BY
    avg_delivery_days ASC;