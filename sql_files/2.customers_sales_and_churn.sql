/* Questions to answer:
1. How many repeat customers do we have vs one-time customers?
2. What's the customer lifetime value?
3. Which cities/states have the most customers?
4. Churn prediction - Customers who haven't ordered in the last 6 months
*/


-- How many repeat customers do we have vs one-time customers?
SELECT
    CASE 
        WHEN order_count = 1 THEN 'One-time customer'
        WHEN order_count = 2 THEN 'Repeat customer (2 orders)'
        WHEN order_count >= 3 THEN 'Repeat customer (3+ orders)'
    END AS customer_type,
    COUNT(customer_unique_id) AS number_of_customers,
    ROUND(COUNT(customer_unique_id) * 100 / SUM(COUNT(customer_unique_id)) OVER(), 2) AS percentage
FROM (
    SELECT
        customers.customer_unique_id,
        COUNT(DISTINCT orders.order_id) AS order_count
    FROM
        customers
    JOIN orders USING (customer_id)
    WHERE
        orders.order_status = 'delivered'
    GROUP BY
        customers.customer_unique_id
) customer_orders
GROUP BY customer_type
ORDER BY number_of_customers DESC;



-- What's the customer lifetime value?
SELECT
    customers.customer_unique_id,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS lifetime_value,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value,
    MIN(orders.order_purchase_timestamp) AS first_purchase_date,
    MAX(orders.order_purchase_timestamp) AS last_purchase_date
FROM
    customers
JOIN orders USING (customer_id)
JOIN order_items USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    customers.customer_unique_id
ORDER BY
    lifetime_value DESC;



-- Which cities/states have the most customers?
SELECT
    customers.customer_state,
    customers.customer_city,
    COUNT(DISTINCT customers.customer_unique_id) AS total_customers,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value
FROM
    customers
JOIN orders USING (customer_id)
JOIN order_items USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    customers.customer_state,
    customers.customer_city
ORDER BY
    total_customers DESC;


-- Churn prediction - Customers who haven't ordered in the last 6 months
WITH dataset_max_date AS (
    SELECT MAX(order_purchase_timestamp)::DATE AS max_date
    FROM orders
)
SELECT
    customers.customer_unique_id,
    customers.customer_state,
    customers.customer_city,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    MAX(orders.order_purchase_timestamp) AS last_purchase_date, -- Calculate days since last order based on the max date in the dataset
    (SELECT max_date FROM dataset_max_date) - MAX(orders.order_purchase_timestamp)::DATE AS days_since_last_order, -- Calculate customer lifetime value for churn prediction
    SUM(order_items.price + order_items.freight_value) AS lifetime_value, -- Calculate average order value for churn prediction
    CASE -- Define churn status based on last purchase date
        WHEN MAX(orders.order_purchase_timestamp) < (SELECT max_date FROM dataset_max_date) - INTERVAL '6 months' THEN 'At Risk'
        WHEN MAX(orders.order_purchase_timestamp) < (SELECT max_date FROM dataset_max_date) - INTERVAL '3 months' THEN 'Warning'
        ELSE 'Active'
    END AS churn_status
FROM
    customers
JOIN orders USING (customer_id)
JOIN order_items USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    customers.customer_unique_id,
    customers.customer_state,
    customers.customer_city
ORDER BY
    days_since_last_order DESC;