/*
Questions to answer:
- Which products/categories are bestsellers?
- Product Category Growth: Month-over-Month (MoM)
*/

-- Which products/categories are bestsellers?
SELECT
    products_trans.product_category_name_english,
    COUNT(DISTINCT order_items.order_id) AS total_orders,
    SUM(order_items.price) AS total_product_revenue,
    SUM(order_items.price + order_items.freight_value) AS total_revenue_with_freight,
    ROUND(AVG(order_items.price), 2) AS avg_product_price,
    ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score
FROM
    order_items
JOIN products USING (product_id)
JOIN product_category_name_translation AS products_trans 
    ON products.product_category_name = products_trans.product_category_name
JOIN orders USING (order_id)
LEFT JOIN order_reviews USING (order_id)
WHERE
    orders.order_status = 'delivered'
GROUP BY
    products_trans.product_category_name_english

-- Product Category Growth: Month-over-Month (MoM)
WITH monthly_category_sales AS (
    SELECT 
        DATE_TRUNC('month', orders.order_purchase_timestamp) AS month,
        products.product_category_name,
        SUM(order_items.price + order_items.freight_value) AS total_revenue,
        COUNT(DISTINCT orders.order_id) AS total_orders
    FROM 
        orders
    JOIN 
        order_items USING (order_id)
    JOIN 
        products USING (product_id)
    WHERE 
        orders.order_status = 'delivered'
        AND products.product_category_name IS NOT NULL
    GROUP BY 
        DATE_TRUNC('month', orders.order_purchase_timestamp),
        products.product_category_name
),
top_5_categories AS (
    SELECT 
        product_category_name
    FROM (
        SELECT 
            product_category_name,
            SUM(total_revenue) AS overall_revenue
        FROM 
            monthly_category_sales
        GROUP BY 
            product_category_name
        ORDER BY 
            overall_revenue DESC
        LIMIT 5
    ) AS top_cats
)
SELECT 
    monthly_category_sales.month,
    monthly_category_sales.product_category_name,
    monthly_category_sales.total_revenue,
    monthly_category_sales.total_orders,
    LAG(monthly_category_sales.total_revenue) OVER (
        PARTITION BY monthly_category_sales.product_category_name 
        ORDER BY monthly_category_sales.month
    ) AS previous_month_revenue,
    ROUND(
        ((monthly_category_sales.total_revenue - LAG(monthly_category_sales.total_revenue) OVER (
            PARTITION BY monthly_category_sales.product_category_name 
            ORDER BY monthly_category_sales.month
        )) * 100.0 / 
        NULLIF(LAG(monthly_category_sales.total_revenue) OVER (
            PARTITION BY monthly_category_sales.product_category_name 
            ORDER BY monthly_category_sales.month
        ), 0)), 
        2
    ) AS mom_growth_rate_pct
FROM 
    monthly_category_sales
INNER JOIN 
    top_5_categories 
    ON monthly_category_sales.product_category_name = top_5_categories.product_category_name
ORDER BY 
    monthly_category_sales.total_revenue DESC,
    monthly_category_sales.month;