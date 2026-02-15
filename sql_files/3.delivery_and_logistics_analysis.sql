/*
Questions to answer:
- What's the average delivery time vs. estimated delivery time?
- Which states have the longest delivery delays?
- How does delivery performance affect review scores?
*/

-- What's the average delivery time vs estimated delivery time?
SELECT
    ROUND(AVG(order_delivered_customer_date::DATE - order_purchase_timestamp::DATE), 2) AS avg_actual_delivery_days,
    ROUND(AVG(order_estimated_delivery_date::DATE - order_purchase_timestamp::DATE), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE), 2) AS avg_delivery_difference,
    COUNT(*) AS total_delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS delayed_percentage
FROM
    orders
WHERE
    order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL;


-- Which states have the longest delivery delays?
SELECT
    customers.customer_state,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    ROUND(AVG(orders.order_delivered_customer_date::DATE - orders.order_purchase_timestamp::DATE), 2) AS avg_actual_delivery_days,
    ROUND(AVG(orders.order_estimated_delivery_date::DATE - orders.order_purchase_timestamp::DATE), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(orders.order_delivered_customer_date::DATE - orders.order_estimated_delivery_date::DATE), 2) AS avg_delay_days,
    SUM(CASE WHEN orders.order_delivered_customer_date > orders.order_estimated_delivery_date THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(SUM(CASE WHEN orders.order_delivered_customer_date > orders.order_estimated_delivery_date THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS delayed_percentage
FROM
    orders
JOIN customers USING (customer_id)
WHERE
    orders.order_status = 'delivered'
    AND orders.order_delivered_customer_date IS NOT NULL
GROUP BY
    customers.customer_state
ORDER BY
    avg_delay_days;

-- How does delivery performance affect review scores?
SELECT
    CASE 
        WHEN orders.order_delivered_customer_date IS NULL 
             OR orders.order_estimated_delivery_date IS NULL THEN 'No Delivery Date'
        WHEN orders.order_delivered_customer_date <= orders.order_estimated_delivery_date THEN 'On Time'
        WHEN (orders.order_delivered_customer_date::DATE - orders.order_estimated_delivery_date::DATE) BETWEEN 1 AND 3 THEN 'Delayed 1-3 days'
        WHEN (orders.order_delivered_customer_date::DATE - orders.order_estimated_delivery_date::DATE) BETWEEN 4 AND 7 THEN 'Delayed 4-7 days'
        WHEN (orders.order_delivered_customer_date::DATE - orders.order_estimated_delivery_date::DATE) > 7 THEN 'Delayed 7+ days'
        ELSE 'Other' -- Catch-all for any unexpected cases
    END AS delivery_performance,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score,
    SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) AS positive_reviews,
    SUM(CASE WHEN order_reviews.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews,
    ROUND(SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS positive_review_percentage
FROM
    orders
LEFT JOIN order_reviews USING (order_id)
WHERE
    orders.order_status = 'delivered'
    AND order_reviews.review_score IS NOT NULL
GROUP BY
    delivery_performance
ORDER BY
    delivery_performance;
