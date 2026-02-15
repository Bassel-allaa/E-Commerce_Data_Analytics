/*
Questions to answer:
- What are the most popular payment methods?
- How do installment plans affect order values?
- Is there a relationship between payment type and order cancellations?
*/

-- What are the most popular payment methods?
SELECT
    order_payments.payment_type,
    COUNT(DISTINCT order_payments.order_id) AS total_orders,
    COUNT(order_payments.payment_sequential) AS total_payments,
    SUM(order_payments.payment_value) AS total_payment_value,
    ROUND(AVG(order_payments.payment_value), 2) AS avg_payment_value,
    ROUND(AVG(order_payments.payment_installments), 2) AS avg_installments,
    ROUND(COUNT(DISTINCT order_payments.order_id) * 100.0 / SUM(COUNT(DISTINCT order_payments.order_id)) OVER(), 2) AS percentage_of_orders,
    ROUND(CAST(PERCENT_RANK() OVER (ORDER BY COUNT(DISTINCT order_payments.order_id)) AS NUMERIC), 4) AS percent_rank_by_orders,
    ROUND(CAST(PERCENT_RANK() OVER (ORDER BY SUM(order_payments.payment_value)) AS NUMERIC), 4) AS percent_rank_by_revenue,
    ROUND(CAST(PERCENT_RANK() OVER (ORDER BY AVG(order_payments.payment_value)) AS NUMERIC), 4) AS percent_rank_by_avg_value
FROM
    order_payments
JOIN orders USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    order_payments.payment_type
ORDER BY
    total_orders DESC;

-- How do installment plans affect order values?
SELECT
    CASE 
        WHEN order_payments.payment_installments = 1 THEN '1 installment (full payment)'
        WHEN order_payments.payment_installments BETWEEN 2 AND 3 THEN '2-3 installments'
        WHEN order_payments.payment_installments BETWEEN 4 AND 6 THEN '4-6 installments'
        WHEN order_payments.payment_installments BETWEEN 7 AND 12 THEN '7-12 installments'
        WHEN order_payments.payment_installments > 12 THEN '12+ installments'
    END AS installment_range,
    COUNT(DISTINCT order_payments.order_id) AS total_orders,
    ROUND(AVG(order_payments.payment_value), 2) AS avg_order_value,
    ROUND(MIN(order_payments.payment_value), 2) AS min_order_value,
    ROUND(MAX(order_payments.payment_value), 2) AS max_order_value,
    ROUND(AVG(order_payments.payment_installments), 2) AS avg_installments_in_range,
    SUM(order_payments.payment_value) AS total_revenue
FROM
    order_payments
JOIN orders USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    installment_range
ORDER BY
    installment_range;

-- Is there a relationship between payment type and order cancellations?
WITH order_payment_summary AS (
    SELECT
        orders.order_id,
        orders.order_status,
        order_payments.payment_type,
        SUM(order_payments.payment_value) AS total_payment_value,
        AVG(order_payments.payment_installments) AS avg_installments
    FROM
        orders
    JOIN order_payments USING (order_id)
    GROUP BY
        orders.order_id,
        orders.order_status,
        order_payments.payment_type
)
SELECT
    payment_type,
    COUNT(order_id) AS total_orders,
    SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    SUM(CASE WHEN order_status = 'unavailable' THEN 1 ELSE 0 END) AS unavailable_orders,
    SUM(CASE WHEN order_status NOT IN ('delivered', 'canceled', 'unavailable') THEN 1 ELSE 0 END) AS other_status_orders,
    ROUND(SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) * 100.0 / COUNT(order_id), 2) AS cancellation_rate,
    ROUND(AVG(total_payment_value), 2) AS avg_payment_value,
    ROUND(AVG(avg_installments), 2) AS avg_installments
FROM
    order_payment_summary
GROUP BY
    payment_type
ORDER BY
    cancellation_rate DESC;