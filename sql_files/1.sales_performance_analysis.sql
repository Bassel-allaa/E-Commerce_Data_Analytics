/* 1. Sales Performance Analysis

- What are the monthly/quarterly sales trends?
- What's the average order value over time?
- Which product categories generate the most revenue?
*/

-- Monthly sales trends and average order value over time
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS month,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value
FROM
    orders
JOIN order_items USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    month
ORDER BY
    month;


-- Product categories generating the most revenue
SELECT
    products_trans.product_category_name_english,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value
FROM
    orders
JOIN order_items USING (order_id)
JOIN products USING (product_id)
JOIN product_category_name_translation AS products_trans 
    ON products.product_category_name = products_trans.product_category_name
WHERE
    orders.order_status = 'delivered'
GROUP BY
    products_trans.product_category_name_english
ORDER BY
    total_revenue DESC;