# Olist E-Commerce Analytics Project

##  Table of Contents
- [Project Overview](#project-overview)
- [Database Architecture](#database-architecture)
- [Business Overview Dashboard](#business-overview-dashboard)
- [Analysis Modules](#analysis-modules)
  - [1. Sales & Product Analysis](#1-sales--product-analysis)
  - [2. Customer Retention & Behavior](#2-customer-retention--behavior)
  - [3. Delivery & Logistics Performance](#3-delivery--logistics-performance)
  - [4. Payment Methods & Preferences](#4-payment-methods--preferences)
  - [5. Sellers Performance](#5-sellers-performance)
- [Key Insights & Findings](#key-insights--findings)
- [Business Recommendations](#business-recommendations)
- [Expected Business Impact](#expected-business-impact)
- [Skills Demonstrated](#skills-demonstrated)
---

##  Project Overview

This project provides a comprehensive analytical framework for Olist, a Brazilian e-commerce platform, utilizing PostgreSQL for data processing and Power BI for visualization. The analysis covers six critical business domains to drive data-informed decision-making.

**Business Objectives:**
- Understand sales trends and revenue drivers
- Identify customer behavior patterns and churn risks
- Optimize delivery and logistics operations
- Analyze product performance and category trends
- Evaluate payment preferences and cancellation patterns
- Assess seller performance and geographic distribution

---


##  Database Architecture

### Database Setup & Schema Design

The project begins with creating a normalized relational database with proper foreign key constraints and indexes for optimal query performance.

**Key Tables:**
- `customers` - Customer demographic information
- `orders` - Order transactions and status
- `order_items` - Individual items within orders
- `order_payments` - Payment transaction details
- `order_reviews` - Customer review scores and comments
- `products` - Product catalog and specifications
- `sellers` - Seller information and location
- `geolocation` - Geographic coordinate data

**Data Quality Measures:**
```sql
-- Foreign Key Constraints
ALTER TABLE orders ADD CONSTRAINT fk_orders_customer 
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

-- Performance Indexes
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
```

### Data Cleaning & Transformation

Comprehensive data cleaning was performed to ensure data quality:

**Key Cleaning Operations:**
- Removed duplicate geolocation entries (1,000,163 → 19,015 unique records)
- Standardized state codes (uppercase, trimmed)
- Handled NULL values in review comments (58,247 NULLs replaced)
- Added calculated columns for delivery delays and on-time delivery flags
- Created date dimension table for time-series analysis

```sql
-- Added delivery performance metrics
ALTER TABLE orders ADD COLUMN delivery_delay_days INTEGER;
UPDATE orders
SET delivery_delay_days = EXTRACT(DAY FROM 
    (order_delivered_customer_date - order_estimated_delivery_date))
WHERE order_delivered_customer_date IS NOT NULL;

-- Created fact table for Power BI optimization
CREATE TABLE fact_orders AS
SELECT 
    orders.order_id,
    orders.customer_id,
    SUM(order_items.price + order_items.freight_value) AS total_order_value,
    COUNT(order_items.order_item_id) AS total_items,
    AVG(order_reviews.review_score) AS avg_review_score
FROM orders
LEFT JOIN order_items USING (order_id)
LEFT JOIN order_reviews USING (order_id)
GROUP BY orders.order_id, orders.customer_id;
```

---

## Business Overview Dashboard

![Dashboard Overview](/images/dashboard_overview.png)

###  Dashboard Overview

The Business Overview Dashboard provides executives and stakeholders with a high-level snapshot of the e-commerce platform's overall health and performance. This dashboard consolidates the most critical KPIs into a single view, enabling quick assessment of business status and trends.

**Dashboard Components:**
- **KPI Cards** - Four primary metrics displayed prominently at the top: Total Revenue ($16M), Total Orders (99K), Average Order Value ($160), and Delivered Orders (96K)
- **Sales Trends Chart** - Time-series visualization showing revenue and order volume evolution over months, revealing seasonality and growth patterns
- **Top Categories Bar Chart** - Revenue ranking of the top 10 product categories, helping identify key revenue drivers
- **Geographic Revenue Map** - Interactive map displaying revenue concentration by state with bubble sizes representing volume
- **Key Performance Metrics Panel** - Additional metrics including Repeat Customer Rate (3%), Churn Rate (71.49%), Active Customer Rate (9.74%), and On-Time Delivery (93.23%)

This dashboard serves as the starting point for deeper analysis, allowing users to identify trends and drill down into specific areas of interest.

##  Analysis Modules

## 1. Sales & Product Analysis

![Sales & Product Analysis](/images/sales_analysis.png)

###  Dashboard Overview

The Sales & Product Analysis Dashboard provides a comprehensive view of revenue performance and product portfolio optimization. This dashboard combines sales trends with category-level insights to help identify top performers, growth opportunities, and potential areas of concern.

**Dashboard Components:**
- **Revenue KPI Cards** - Quick reference metrics: Total Revenue ($16M), Total Orders (99K), and Average Order Value ($160)
- **Revenue & MoM Growth Trends** - Dual-axis chart showing monthly revenue bars alongside month-over-month growth rate line, revealing both absolute performance and growth velocity
- **Top 10 Categories Bar Chart** - Horizontal bars ranking categories by revenue contribution with exact dollar values
- **Revenue Rank Table** - Detailed breakdown showing rank, category name, total revenue (with blue magnitude bars), and revenue share percentage (with green proportion bars)
- **Category Filter** - Dropdown selector enabling drill-down analysis of specific product categories

This dashboard enables product managers and executives to understand which categories drive revenue, identify trends in category performance, and make data-driven decisions about inventory, marketing focus, and seller recruitment.

###  SQL Analysis Breakdown

#### Monthly Sales Trends & Average Order Value
```sql
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS month,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value
FROM orders
JOIN order_items USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY month
ORDER BY month;
```

**What this query does:**
- Aggregates sales data by month using `DATE_TRUNC()`
- Calculates total orders, revenue, and average order value
- Filters only successfully delivered orders
- Provides time-series data for trend analysis

#### Top Revenue-Generating Categories
```sql
SELECT
    products_trans.product_category_name_english,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value
FROM orders
JOIN order_items USING (order_id)
JOIN products USING (product_id)
JOIN product_category_name_translation AS products_trans 
    ON products.product_category_name = products_trans.product_category_name
WHERE orders.order_status = 'delivered'
GROUP BY products_trans.product_category_name_english
ORDER BY total_revenue DESC;
```

**What this query does:**
- Joins multiple tables to link orders with product categories
- Translates Portuguese category names to English
- Ranks categories by total revenue contribution
- Calculates average order value per category

#### Best-Selling Categories with Review Performance
```sql
SELECT
    products_trans.product_category_name_english,
    COUNT(DISTINCT order_items.order_id) AS total_orders,
    SUM(order_items.price) AS total_product_revenue,
    SUM(order_items.price + order_items.freight_value) AS total_revenue_with_freight,
    ROUND(AVG(order_items.price), 2) AS avg_product_price,
    ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score
FROM order_items
JOIN products USING (product_id)
JOIN product_category_name_translation AS products_trans 
    ON products.product_category_name = products_trans.product_category_name
JOIN orders USING (order_id)
LEFT JOIN order_reviews USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY products_trans.product_category_name_english
ORDER BY total_revenue_with_freight DESC;
```

**What this query does:**
- Aggregates sales by product category
- Calculates revenue with and without freight
- Computes average product price per category
- Includes customer review scores for quality assessment
- Ranks categories by total revenue contribution

#### Month-over-Month Category Growth Analysis
```sql
WITH monthly_category_sales AS (
    SELECT 
        DATE_TRUNC('month', orders.order_purchase_timestamp) AS month,
        products.product_category_name,
        SUM(order_items.price + order_items.freight_value) AS total_revenue,
        COUNT(DISTINCT orders.order_id) AS total_orders
    FROM orders
    JOIN order_items USING (order_id)
    JOIN products USING (product_id)
    WHERE orders.order_status = 'delivered'
        AND products.product_category_name IS NOT NULL
    GROUP BY 
        DATE_TRUNC('month', orders.order_purchase_timestamp),
        products.product_category_name
),
top_5_categories AS (
    SELECT product_category_name
    FROM (
        SELECT 
            product_category_name,
            SUM(total_revenue) AS overall_revenue
        FROM monthly_category_sales
        GROUP BY product_category_name
        ORDER BY overall_revenue DESC
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
        ((monthly_category_sales.total_revenue - LAG(monthly_category_sales.total_revenue) 
            OVER (PARTITION BY monthly_category_sales.product_category_name 
            ORDER BY monthly_category_sales.month)
        ) * 100.0 / 
        NULLIF(LAG(monthly_category_sales.total_revenue) 
            OVER (PARTITION BY monthly_category_sales.product_category_name 
            ORDER BY monthly_category_sales.month), 0)), 
        2
    ) AS mom_growth_rate_pct
FROM monthly_category_sales
INNER JOIN top_5_categories 
    ON monthly_category_sales.product_category_name = 
       top_5_categories.product_category_name
ORDER BY 
    monthly_category_sales.total_revenue DESC,
    monthly_category_sales.month;
```

**What this query does:**
- Uses CTE to aggregate monthly sales by category
- Filters to top 5 categories by overall revenue
- Applies `LAG()` window function to access previous month's data
- Calculates percentage growth month-over-month
- Identifies trending categories and seasonal patterns

### Key Insights

**Overall Revenue Performance:**
- **Total Revenue:** $16M over the analysis period
- **Total Orders:** 99,441 delivered orders
- **Average Order Value:** $160
- **Delivered Orders:** 96,478 (97% success rate)

**Sales Trends:**
- Peak sales occurred in **November 2017** with revenue exceeding $1.5M
- Clear seasonal patterns with Q4 showing strongest performance
- Steady decline observed from January 2018 onwards
- Month-over-month volatility suggests need for demand forecasting
- **Revenue & MoM Growth chart** shows:
  - Early months (2016-2017) had peak performance
  - Declining trend from late 2017 onwards
  - Negative MoM growth in recent months (green line dips below zero)
  - Seasonal volatility visible in growth rate fluctuations

**Top Categories by Revenue:**
1. **Health & Beauty** - $1.45M (9.10% of total revenue)
   - Highest revenue generator
   - Consistent strong performance
2. **Watches & Gifts** - $1.31M (8.24%)
   - Popular gift category
   - Seasonal spikes likely
3. **Bed, Bath, Table** - $1.28M (7.84%)
   - Home goods staple
   - Stable demand
4. **Sports & Leisure** - $1.17M (7.30%)
   - Active lifestyle products
   - Growth opportunity
5. **Computers & Accessories** - $1.07M (6.69%)
   - High-value category
   - Tech-savvy audience

**Revenue Distribution:**
- Top 10 categories account for ~65% of total revenue
- Long tail of smaller categories (remaining 35%)
- Opportunity to consolidate or optimize smaller categories
- Fairly even distribution among top 10 (3.69% - 9.10%)
- No single category dominates (diversified portfolio)

**Geographic Distribution:**
- **Primary market:** Brazil (South America)
- **Concentrated revenue** in São Paulo region (largest bubble on map)
- Significant opportunity for geographic expansion

**Strategic Observations:**
- High-margin categories (tech, health) performing well
- Home goods showing stable demand
- Need to investigate decline in recent months
- Opportunity to boost underperforming categories

###  Dashboard Features

**Top KPI Cards:**
- Real-time metrics for revenue, orders, and AOV
- Color-coded for quick status assessment

**Sales Trends Visualization:**
- Dual-axis chart showing revenue bars and order volume line
- Enables correlation analysis between volume and value

**Revenue & MoM Growth Trends:**
- Dual-axis visualization (bars for revenue, line for growth rate)
- Time-series view showing performance evolution
- Highlights periods of growth vs. decline

**Category Performance:**
- Horizontal bar chart ranking top 10 categories
- Revenue values displayed for precise comparison

**Revenue Rank Table:**
- Sortable columns for rank, category, revenue, and share %
- Revenue visualized with blue bars (magnitude)
- Share % visualized with green bars (proportion)
- Provides precise numerical data alongside visuals

**Revenue by State Map:**
- Geographic heat map with bubble sizes representing revenue concentration
- Interactive state-level filtering

**Category Selector:**
- Dropdown filter at top of dashboard
- Enables drill-down analysis by specific category
- Updates all visuals dynamically

---

## 2. Customer Retention & Behavior

![Customer Retention](/images/customer_behavior.png)

###  Dashboard Overview

The Customer Retention & Behavior Dashboard analyzes customer loyalty, lifetime value, and churn risk. This dashboard is critical for understanding customer behavior patterns and developing retention strategies to maximize long-term revenue.

**Dashboard Components:**
- **Customer KPI Cards** - Critical metrics: Total Customers (96K), Active Customer Rate (9.74%), Repeat Customer Rate (3%), and Churn Rate (71.49%)
- **Customer Type Donut Chart** - Visual breakdown showing overwhelming dominance of one-time customers (94%) versus repeat customers (6%)
- **Churn Status Donut Chart** - Risk segmentation displaying Active (9.52%), Warning (18.57%), and At Risk (69.27%) customers with color coding
- **CLV Distribution Scatter Plot** - Visualization mapping total orders per customer (X-axis) against lifetime value (Y-axis), color-coded by customer type
- **Customer Distribution by State Map** - Geographic bubble map showing customer concentration, with heavy focus in Southeast Brazil
- **Customer Type Filters** - Toggle buttons to filter analysis between one-time customers, repeat customers (2 orders), and repeat customers (3+ orders)

This dashboard enables marketing and CRM teams to identify high-value customers, prioritize retention efforts, segment customers by risk level, and develop targeted re-engagement campaigns.

###  SQL Analysis Breakdown

#### Customer Segmentation: One-time vs. Repeat Customers
```sql
SELECT
    CASE 
        WHEN order_count = 1 THEN 'One-time customer'
        WHEN order_count = 2 THEN 'Repeat customer (2 orders)'
        WHEN order_count >= 3 THEN 'Repeat customer (3+ orders)'
    END AS customer_type,
    COUNT(customer_unique_id) AS number_of_customers,
    ROUND(COUNT(customer_unique_id) * 100.0 / 
        SUM(COUNT(customer_unique_id)) OVER(), 2) AS percentage
FROM (
    SELECT
        customers.customer_unique_id,
        COUNT(DISTINCT orders.order_id) AS order_count
    FROM customers
    JOIN orders USING (customer_id)
    WHERE orders.order_status = 'delivered'
    GROUP BY customers.customer_unique_id
) customer_orders
GROUP BY customer_type
ORDER BY number_of_customers DESC;
```

**What this query does:**
- Uses nested query to count orders per unique customer
- Segments customers into three categories using `CASE` statement
- Calculates percentage distribution with window function `OVER()`
- Identifies customer loyalty patterns

#### Customer Lifetime Value (CLV) Analysis
```sql
SELECT
    customers.customer_unique_id,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    SUM(order_items.price + order_items.freight_value) AS lifetime_value,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value,
    MIN(orders.order_purchase_timestamp) AS first_purchase_date,
    MAX(orders.order_purchase_timestamp) AS last_purchase_date
FROM customers
JOIN orders USING (customer_id)
JOIN order_items USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY customers.customer_unique_id
ORDER BY lifetime_value DESC;
```

**What this query does:**
- Aggregates all purchases per unique customer
- Calculates total lifetime value (LTV)
- Tracks customer purchase timeline
- Identifies high-value customers for retention strategies

#### Churn Risk Analysis
```sql
WITH dataset_max_date AS (
    SELECT MAX(order_purchase_timestamp)::DATE AS max_date
    FROM orders
)
SELECT
    customers.customer_unique_id,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    MAX(orders.order_purchase_timestamp) AS last_purchase_date,
    (SELECT max_date FROM dataset_max_date) - 
        MAX(orders.order_purchase_timestamp)::DATE AS days_since_last_order,
    SUM(order_items.price + order_items.freight_value) AS lifetime_value,
    CASE 
        WHEN MAX(orders.order_purchase_timestamp) < 
            (SELECT max_date FROM dataset_max_date) - INTERVAL '6 months' 
            THEN 'At Risk'
        WHEN MAX(orders.order_purchase_timestamp) < 
            (SELECT max_date FROM dataset_max_date) - INTERVAL '3 months' 
            THEN 'Warning'
        ELSE 'Active'
    END AS churn_status
FROM customers
JOIN orders USING (customer_id)
JOIN order_items USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY customers.customer_unique_id
ORDER BY days_since_last_order DESC;
```

**What this query does:**
- Uses CTE to establish dataset reference date
- Calculates recency of last purchase
- Segments customers by churn risk level
- Combines recency with lifetime value for prioritization

### Key Insights

**Customer Composition:**
- **Total Unique Customers:** 96,096
- **One-time Customers:** 94% (91,000+)
- **Repeat Customers:** 3% (only ~3,000 customers)
- **Active Customer Rate:** 9.74%

**Churn Analysis:**
- **Churn Rate:** 71.49% - CRITICAL ISSUE
- **At-Risk Customers:** 69.27% (haven't ordered in 6+ months)
- **Warning Status:** 18.57% (inactive for 3-6 months)
- **Active Customers:** Only 9.52%

**Customer Lifetime Value Distribution:**
- Most customers cluster in the $0-$50k CLV range
- Scatter plot shows high concentration of one-time, low-value customers
- Few high-value repeat customers (outliers in purple/green)

**Geographic Distribution:**
- Heavy concentration in **Southeast Brazil**
- São Paulo region dominates customer base
- Limited presence in other regions/countries

### Dashboard Features

**Segmentation Cards:**
- Customer count, active rate, repeat rate, and churn rate
- Filter toggles for one-time vs. repeat customer analysis

**Customer Type Donut Chart:**
- Visual representation of customer composition
- 94% one-time vs. 6% repeat customers

**Churn Status Donut Chart:**
- Risk-level segmentation (Active/Warning/At Risk)
- Color-coded for urgency (blue=active, yellow=warning, red=at risk)

**CLV Distribution Scatter Plot:**
- X-axis: Total orders per customer
- Y-axis: Customer lifetime value
- Color segments by customer type
- Identifies high-value customer clusters

---

## 3. Delivery & Logistics Performance

![Delivery Performance](/images/delivery_performance.png)

### Dashboard Overview

The Delivery & Logistics Performance Dashboard provides detailed insights into fulfillment operations, delivery times, and logistics efficiency. This dashboard helps operations teams identify bottlenecks, track performance against estimates, and understand how delivery performance impacts customer satisfaction.

**Dashboard Components:**
- **Delivery KPI Cards** - Core metrics: Average Actual Delivery Days (-10.96), Average Estimated Delivery Days (24.37), Average Delivery Difference (-11.88 days early!), and On-Time Delivery Rate (93.23%)
- **Average Delay Days by State** - Horizontal bar chart ranking states by delivery performance, identifying geographic challenges
- **Delivery Performance vs. Reviews** - Clustered bar chart correlating delivery timeliness with review scores (positive vs negative reviews)
- **State Performance Heatmap** - Comprehensive table with color-coded cells showing average delay days, on-time percentage, review scores, and order volume by state
- **State Filter** - Dropdown selector for drilling down into specific state performance

This dashboard enables logistics managers to optimize delivery routes, identify underperforming regions, and quantify the relationship between delivery speed and customer satisfaction.

### SQL Analysis Breakdown

#### Overall Delivery Performance Metrics
```sql
SELECT
    ROUND(AVG(order_delivered_customer_date::DATE - 
        order_purchase_timestamp::DATE), 2) AS avg_actual_delivery_days,
    ROUND(AVG(order_estimated_delivery_date::DATE - 
        order_purchase_timestamp::DATE), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(order_delivered_customer_date::DATE - 
        order_estimated_delivery_date::DATE), 2) AS avg_delivery_difference,
    COUNT(*) AS total_delivered_orders,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date 
        THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date 
        THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS delayed_percentage
FROM orders
WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL;
```

**What this query does:**
- Calculates actual vs. estimated delivery time using date arithmetic
- Measures delivery variance (ahead or behind schedule)
- Aggregates on-time vs. delayed delivery counts
- Provides KPIs for logistics efficiency

#### State-Level Delivery Analysis
```sql
SELECT
    customers.customer_state,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    ROUND(AVG(orders.order_delivered_customer_date::DATE - 
        orders.order_purchase_timestamp::DATE), 2) AS avg_actual_delivery_days,
    ROUND(AVG(orders.order_estimated_delivery_date::DATE - 
        orders.order_purchase_timestamp::DATE), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(orders.order_delivered_customer_date::DATE - 
        orders.order_estimated_delivery_date::DATE), 2) AS avg_delay_days,
    SUM(CASE WHEN orders.order_delivered_customer_date > 
        orders.order_estimated_delivery_date THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(SUM(CASE WHEN orders.order_delivered_customer_date > 
        orders.order_estimated_delivery_date THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*), 2) AS delayed_percentage
FROM orders
JOIN customers USING (customer_id)
WHERE orders.order_status = 'delivered'
    AND orders.order_delivered_customer_date IS NOT NULL
GROUP BY customers.customer_state
ORDER BY avg_delay_days;
```

**What this query does:**
- Groups delivery metrics by customer state
- Identifies geographic regions with delivery challenges
- Ranks states from best to worst performance
- Enables targeted logistics improvements

#### Delivery Performance Impact on Reviews
```sql
SELECT
    CASE 
        WHEN orders.order_delivered_customer_date IS NULL 
             OR orders.order_estimated_delivery_date IS NULL 
             THEN 'No Delivery Date'
        WHEN orders.order_delivered_customer_date <= 
             orders.order_estimated_delivery_date THEN 'On Time'
        WHEN (orders.order_delivered_customer_date::DATE - 
             orders.order_estimated_delivery_date::DATE) BETWEEN 1 AND 3 
             THEN 'Delayed 1-3 days'
        WHEN (orders.order_delivered_customer_date::DATE - 
             orders.order_estimated_delivery_date::DATE) BETWEEN 4 AND 7 
             THEN 'Delayed 4-7 days'
        WHEN (orders.order_delivered_customer_date::DATE - 
             orders.order_estimated_delivery_date::DATE) > 7 
             THEN 'Delayed 7+ days'
    END AS delivery_performance,
    COUNT(DISTINCT orders.order_id) AS total_orders,
    ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score,
    SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) 
        AS positive_reviews,
    SUM(CASE WHEN order_reviews.review_score <= 2 THEN 1 ELSE 0 END) 
        AS negative_reviews,
    ROUND(SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*), 2) AS positive_review_percentage
FROM orders
LEFT JOIN order_reviews USING (order_id)
WHERE orders.order_status = 'delivered'
    AND order_reviews.review_score IS NOT NULL
GROUP BY delivery_performance
ORDER BY delivery_performance;
```

**What this query does:**
- Categorizes orders by delivery timeliness
- Correlates delivery performance with review scores
- Quantifies impact of delays on customer satisfaction
- Provides data for SLA optimization

### Key Insights

**Delivery Performance Overview:**
- **Average Actual Delivery:** -10.96 days (arrives ~11 days early on average)
- **Average Estimated Delivery:** 24.37 days
- **Average Delivery Difference:** -11.88 days (consistently ahead of estimates)
- **On-Time Delivery Rate:** 93.23% - EXCELLENT

**State-Level Performance:**
- **Best performers:** PR (20.4 days), RO (20.5 days), MG (21.0 days)
- **Worst performers:** RR (29.3 days), AP (27.2 days), AM (26.4 days)
- Remote northern states show significantly longer delivery times
- Heatmap reveals delivery time correlates with geographic remoteness

**Delivery vs. Review Score Correlation:**
- **On-Time Deliveries:** High positive review rate (~1000+ positive reviews)
- **Delayed 1-3 days:** Lower positive review percentage (~400 positive reviews)
- **Delayed 4-7 days:** Further decrease in satisfaction
- **Delayed 7+ days:** Significant drop in review scores
- Clear correlation: delivery timeliness directly impacts customer satisfaction

**Key Findings:**
- Conservative delivery estimates lead to high on-time performance
- Could adjust estimates to be more accurate (currently overly cautious)
- Remote regions need logistics infrastructure investment
- Delivery performance is a major satisfaction driver

###  Dashboard Features

**Top KPI Cards:**
- Actual vs. Estimated delivery days comparison
- Average delivery difference with trend indicator
- On-time delivery percentage with color coding

**Average Delay Days by State:**
- Horizontal bar chart ranking all states
- Values displayed for precise comparison
- Enables quick identification of problem regions

**Delivery Performance vs. Reviews:**
- Clustered bar chart comparing positive and negative reviews
- X-axis categories: On Time, Delayed 1-3, 4-7, 7+ days
- Visual proof of delivery impact on satisfaction

**State Performance Heatmap:**
- Combined view: Average delay days, on-time %, review scores, and order volume
- Color-coded cells (red=poor, yellow=moderate, green=excellent)
- Sortable by any metric for flexible analysis

---

## 4. Payment Methods & Preferences

![Payments Dashboard](/images/payment_preferences.png)

### Dashboard Overview

The Payment Methods & Preferences Dashboard analyzes customer payment behaviors, preferences, and their relationship with order completion rates. This dashboard helps finance and product teams optimize payment options, identify friction points, and understand customer payment patterns.

**Dashboard Components:**
- **Payment KPI Cards** - Essential metrics: Total Orders (99K), Average Order Value ($160), Canceled Orders (625), and Cancellation Rate (0.63%)
- **Payment Method Distribution Donut Chart** - Visual breakdown showing credit card dominance (74%), boleto (19.5%), voucher (5.8%), and debit (1.5%)
- **Orders & Cancellation by Payment** - Dual visualization with bars showing total orders by payment type and line graph showing cancellation rates
- **Payment Performance Table** - Detailed breakdown with columns for payment type, total orders, average payment value, cancellation rate percentage, and total revenue (with color-coded bars)
- **Payment Type Filter** - Dropdown selector for analyzing specific payment methods

This dashboard enables teams to understand which payment methods drive conversions, identify payment-related cancellation patterns, and make data-driven decisions about payment gateway partnerships and checkout optimization.

###  SQL Analysis Breakdown

#### Payment Method Popularity Analysis
```sql
SELECT
    order_payments.payment_type,
    COUNT(DISTINCT order_payments.order_id) AS total_orders,
    COUNT(order_payments.payment_sequential) AS total_payments,
    SUM(order_payments.payment_value) AS total_payment_value,
    ROUND(AVG(order_payments.payment_value), 2) AS avg_payment_value,
    ROUND(AVG(order_payments.payment_installments), 2) AS avg_installments,
    ROUND(COUNT(DISTINCT order_payments.order_id) * 100.0 / 
        SUM(COUNT(DISTINCT order_payments.order_id)) OVER(), 2) 
        AS percentage_of_orders,
    ROUND(CAST(PERCENT_RANK() OVER 
        (ORDER BY COUNT(DISTINCT order_payments.order_id)) AS NUMERIC), 4) 
        AS percent_rank_by_orders,
    ROUND(CAST(PERCENT_RANK() OVER 
        (ORDER BY SUM(order_payments.payment_value)) AS NUMERIC), 4) 
        AS percent_rank_by_revenue
FROM order_payments
JOIN orders USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY order_payments.payment_type
ORDER BY total_orders DESC;
```

**What this query does:**
- Aggregates payment data by payment type
- Counts distinct orders and total payment transactions
- Calculates average payment value and installment usage
- Uses window functions to compute percentage distribution
- Ranks payment methods by popularity and revenue contribution

#### Installment Plan Analysis
```sql
SELECT
    CASE 
        WHEN order_payments.payment_installments = 1 
            THEN '1 installment (full payment)'
        WHEN order_payments.payment_installments BETWEEN 2 AND 3 
            THEN '2-3 installments'
        WHEN order_payments.payment_installments BETWEEN 4 AND 6 
            THEN '4-6 installments'
        WHEN order_payments.payment_installments BETWEEN 7 AND 12 
            THEN '7-12 installments'
        WHEN order_payments.payment_installments > 12 
            THEN '12+ installments'
    END AS installment_range,
    COUNT(DISTINCT order_payments.order_id) AS total_orders,
    ROUND(AVG(order_payments.payment_value), 2) AS avg_order_value,
    ROUND(MIN(order_payments.payment_value), 2) AS min_order_value,
    ROUND(MAX(order_payments.payment_value), 2) AS max_order_value,
    ROUND(AVG(order_payments.payment_installments), 2) AS avg_installments_in_range,
    SUM(order_payments.payment_value) AS total_revenue
FROM order_payments
JOIN orders USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY installment_range
ORDER BY installment_range;
```

**What this query does:**
- Categorizes orders by installment plan range
- Analyzes relationship between installments and order value
- Calculates min/max/avg order values per installment bucket
- Identifies whether higher-value orders use more installments

#### Payment Type vs. Cancellation Correlation
```sql
WITH order_payment_summary AS (
    SELECT
        orders.order_id,
        orders.order_status,
        order_payments.payment_type,
        SUM(order_payments.payment_value) AS total_payment_value,
        AVG(order_payments.payment_installments) AS avg_installments
    FROM orders
    JOIN order_payments USING (order_id)
    GROUP BY orders.order_id, orders.order_status, order_payments.payment_type
)
SELECT
    payment_type,
    COUNT(order_id) AS total_orders,
    SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) 
        AS delivered_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) 
        AS canceled_orders,
    SUM(CASE WHEN order_status = 'unavailable' THEN 1 ELSE 0 END) 
        AS unavailable_orders,
    ROUND(SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(order_id), 2) AS cancellation_rate,
    ROUND(AVG(total_payment_value), 2) AS avg_payment_value,
    ROUND(AVG(avg_installments), 2) AS avg_installments
FROM order_payment_summary
GROUP BY payment_type
ORDER BY cancellation_rate DESC;
```

**What this query does:**
- Uses CTE to summarize payment details per order
- Counts orders by status (delivered, canceled, unavailable)
- Calculates cancellation rate by payment type
- Identifies if certain payment methods have higher failure rates

### Key Insights

**Payment Method Distribution:**
- **Credit Card:** 74% dominance (73,854 orders)
  - Clear customer preference
  - Most trusted payment method
- **Boleto:** 19.5% (19,784 orders)
  - Brazilian payment method (bank slip)
  - Popular alternative to cards
- **Voucher:** 5.8% (5,879 orders)
  - Gift cards/promotional codes
- **Debit Card:** 1.5% (1,485 orders)
  - Surprisingly low adoption

**Order Value by Payment Type:**
- All payment types have similar average order value (~$160)
- Credit card: $165 AOV
- Boleto: $142 AOV (slightly lower)
- Voucher: $65.37 AOV (promotional/gift orders)
- Debit: $140.27 AOV

**Cancellation Analysis:**
- **Overall Cancellation Rate:** 0.63% (very low - excellent!)
- **Credit Card Cancellations:** 74,844 orders, minimal cancellation
- **Debit Card:** Highest cancellation rate by percentage
- **Voucher:** Lowest cancellation (promotional orders completed)
- Payment method does NOT significantly impact cancellation risk

**Installment Insights:**
- Average installments across payment types: ~3-4 months
- Credit cards facilitate installment plans
- Boleto typically single payment (cash-equivalent)
- Installments enable higher-value purchases

**Revenue by Payment Type:**
- Credit Card: $12.4M (77% of revenue)
- Boleto: $2.9M (18% of revenue)
- Voucher: $384K (2.4% of revenue)
- Debit Card: $208K (1.3% of revenue)

###  Dashboard Features

**Payment Method Distribution Donut Chart:**
- Visual breakdown of payment preferences
- Percentage labels for each segment
- Color-coded for easy identification

**Orders & Cancellation by Payment:**
- Clustered bar chart showing total orders (blue bars)
- Line graph overlay for cancellation rate by payment type
- Dual-axis for volume vs. rate comparison

**Payment Type Performance Table:**
- Columns: Payment Type, Total Orders, Avg Payment Value, Cancellation Rate %, Total Revenue
- Color bars indicating relative performance
- Sortable for flexible analysis

**Payment Selector:**
- Dropdown filter to analyze specific payment methods
- Updates all visualizations dynamically

---

## 5. Sellers Performance

![Sellers Dashboard](/images/sellers_performance.png)

### Dashboard Overview

The Sellers Performance Dashboard provides comprehensive insights into the seller ecosystem, including geographic distribution, revenue performance, and quality metrics. This dashboard helps marketplace managers identify top performers, recruit strategically, and maintain platform quality.

**Dashboard Components:**
- **Seller KPI Cards** - Key metrics: Total Sellers (3K), States with Sellers (23), Average Revenue per Seller ($5.19K), and Average Review Score (4.16/5.0)
- **Seller Geographic Distribution Map** - Interactive bubble map showing seller concentration across regions, with São Paulo region showing highest density
- **Top Cities by Revenue** - Horizontal bar chart ranking cities by total revenue generated, highlighting key seller markets
- **Seller State Performance Table** - Comprehensive breakdown with columns for seller state, total revenue (with green color bars), total orders, average review score, and total seller count
- **Seller State Filter** - Dropdown selector for analyzing specific geographic regions

This dashboard enables marketplace teams to identify high-potential markets for seller recruitment, understand geographic revenue distribution, assess seller quality by region, and make strategic decisions about regional growth initiatives.

### SQL Analysis Breakdown

#### Top Sellers by Revenue and Review Scores
```sql
SELECT
    order_items.seller_id,
    COUNT(DISTINCT order_items.order_id) AS total_orders,
    COUNT(DISTINCT order_items.product_id) AS unique_products_sold,
    SUM(order_items.price + order_items.freight_value) AS total_revenue,
    ROUND(AVG(order_items.price + order_items.freight_value), 2) AS avg_order_value,
    ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score,
    COUNT(order_reviews.review_id) AS total_reviews,
    SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) 
        AS positive_reviews,
    SUM(CASE WHEN order_reviews.review_score <= 2 THEN 1 ELSE 0 END) 
        AS negative_reviews,
    ROUND(SUM(CASE WHEN order_reviews.review_score >= 4 THEN 1 ELSE 0 END) 
        * 100.0 / NULLIF(COUNT(order_reviews.review_id), 0), 2) 
        AS positive_review_percentage
FROM order_items
JOIN orders USING (order_id)
LEFT JOIN order_reviews USING (order_id)
WHERE orders.order_status = 'delivered'
GROUP BY order_items.seller_id
HAVING COUNT(DISTINCT order_items.order_id) >= 10  
-- Filter for sellers with at least 10 orders
ORDER BY total_revenue DESC
LIMIT 20;
```

**What this query does:**
- Aggregates performance metrics per seller
- Counts total and unique products sold
- Calculates revenue and average order value
- Computes review score statistics
- Filters for established sellers (10+ orders)
- Returns top 20 by revenue

#### Seller Rating Correlation with Sales Performance
```sql
WITH seller_performance AS (
    SELECT
        order_items.seller_id,
        SUM(order_items.price + order_items.freight_value) AS total_revenue,
        COUNT(DISTINCT order_items.order_id) AS total_orders,
        ROUND(AVG(order_reviews.review_score), 2) AS avg_review_score,
        COUNT(order_reviews.review_id) AS total_reviews
    FROM order_items
    JOIN orders USING (order_id)
    LEFT JOIN order_reviews USING (order_id)
    WHERE orders.order_status = 'delivered'
    GROUP BY order_items.seller_id
    HAVING COUNT(order_reviews.review_id) >= 5  
    -- At least 5 reviews for reliable scoring
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
FROM seller_performance
GROUP BY review_category
ORDER BY avg_review_score_in_category DESC;
```

**What this query does:**
- Creates CTE to aggregate seller-level metrics
- Categorizes sellers by review score tiers
- Analyzes correlation between ratings and revenue
- Calculates average performance per rating category
- Tests hypothesis: higher ratings → higher sales

#### Seller Location and Delivery Performance
```sql
WITH seller_delivery_performance AS (
    SELECT
        sellers.seller_id,
        sellers.seller_city,
        sellers.seller_state,
        COUNT(DISTINCT orders.order_id) AS total_orders,
        ROUND(AVG(EXTRACT(EPOCH FROM 
            (orders.order_delivered_customer_date - 
             orders.order_purchase_timestamp)) / 86400), 2) 
             AS avg_delivery_days,
        ROUND(AVG(EXTRACT(EPOCH FROM 
            (orders.order_estimated_delivery_date - 
             orders.order_purchase_timestamp)) / 86400), 2) 
             AS avg_estimated_delivery_days,
        SUM(CASE WHEN orders.order_delivered_customer_date <= 
            orders.order_estimated_delivery_date THEN 1 ELSE 0 END) 
            AS on_time_deliveries,
        ROUND(SUM(CASE WHEN orders.order_delivered_customer_date <= 
            orders.order_estimated_delivery_date THEN 1 ELSE 0 END) 
            * 100.0 / COUNT(DISTINCT orders.order_id), 2) 
            AS on_time_percentage
    FROM sellers
    JOIN order_items USING (seller_id)
    JOIN orders USING (order_id)
    WHERE orders.order_status = 'delivered'
        AND orders.order_delivered_customer_date IS NOT NULL
        AND orders.order_estimated_delivery_date IS NOT NULL
    GROUP BY sellers.seller_id, sellers.seller_city, sellers.seller_state
    HAVING COUNT(DISTINCT orders.order_id) >= 10
)
SELECT
    seller_state,
    COUNT(seller_id) AS number_of_sellers,
    SUM(total_orders) AS total_orders_from_state,
    ROUND(AVG(avg_delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(avg_estimated_delivery_days), 2) AS avg_estimated_days,
    SUM(on_time_deliveries) AS total_on_time_deliveries
FROM seller_delivery_performance
GROUP BY seller_state
HAVING COUNT(seller_id) >= 5
ORDER BY avg_delivery_days ASC;
```

**What this query does:**
- Analyzes delivery performance by seller location
- Calculates average delivery times from seller states
- Computes on-time delivery percentages
- Identifies which seller states have best logistics
- Uses nested CTE for multi-level aggregation

###  Key Insights

**Seller Overview:**
- **Total Sellers:** 2,970
- **States with Sellers:** 23
- **Average Revenue per Seller:** $5.19K
- **Average Review Score:** 4.16/5.0 (good overall quality)

**Geographic Distribution:**
- **Heavy concentration** in Southeast Brazil (São Paulo region)
- Large blue bubble dominates seller map
- Limited seller presence in other regions
- Top cities by revenue:
  1. **São Paulo** - Dominant seller hub
  2. **Ibitinga** - Textile/home goods center
  3. **Curitiba** - Southern region seller base
  4. **Rio de Janeiro** - Second major city
  5. **Guarulhos** - São Paulo metro area

**Seller Performance by State:**
- **SP (São Paulo):** 1,044 sellers, $1.5M revenue, 70,788 orders
- **MG (Minas Gerais):** 336 sellers, $948K revenue, 7,573 orders
- **PR (Paraná):** 231 sellers, $663K revenue, 4,637 orders
- **RJ (Rio de Janeiro):** 214 sellers, $951K revenue, 4,353 orders
- **SC (Santa Catarina):** 184 sellers, $776K revenue, 3,567 orders

**Seller Quality Metrics:**
- Most sellers maintain 4.0+ review scores
- Sellers with higher ratings tend to have:
  - More consistent order volume
  - Better delivery performance
  - Higher customer retention
- Review score of 4.16 indicates good marketplace quality control

**Revenue Concentration:**
- Top cities generate disproportionate share of revenue
- São Paulo alone accounts for significant portion
- Long tail of smaller sellers in secondary cities
- Opportunity to develop sellers in underrepresented regions

**Performance Insights:**
- Seller location impacts delivery time
- Proximity to major logistics hubs correlates with better performance
- Sellers in remote areas face delivery challenges
- Geographic diversification could improve service coverage

###  Dashboard Features

**Seller Geographic Distribution Map:**
- Bubble map showing seller concentration by location
- Bubble size represents number of sellers or revenue
- Interactive hover for city-level details

**Top Cities by Revenue:**
- Horizontal bar chart ranking cities
- Revenue values displayed for comparison
- Highlights key seller markets

**Seller State Performance Table:**
- Comprehensive view: State, Total Revenue, Total Orders, Avg Review Score, Total Sellers
- Color-coded performance indicators (green for high performers)
- Sortable columns for flexible analysis

**State Selector:**
- Dropdown filter to focus on specific seller states
- Updates all visuals dynamically

---

##  Key Insights & Findings

### Critical Business Metrics Summary

| Metric | Value | Status | Priority |
|--------|-------|--------|----------|
| **Total Revenue** | $16M |  Strong | Maintain |
| **Average Order Value** | $160 |  Healthy | Optimize |
| **On-Time Delivery** | 93.23% |  Excellent | Maintain |
| **Churn Rate** | 71.49% |  Critical | **HIGH** |
| **Repeat Customer Rate** | 3% |  Very Low | **HIGH** |
| **Cancellation Rate** | 0.63% |  Excellent | Monitor |
| **Avg Review Score** | 4.16/5 |  Good | Improve |

###  Top 5 Strategic Insights

#### 1. **Customer Retention Crisis**
- **Finding:** 94% of customers are one-time buyers; only 3% return
- **Impact:** Massive revenue leakage - acquiring new customers costs 5-25x more than retaining existing ones
- **Root Causes:**
  - No loyalty program or incentives to return
  - Lack of post-purchase engagement
  - No personalized marketing
- **Opportunity:** If repeat rate increased to just 10%, revenue could grow by $4-5M annually

#### 2. **Delivery Excellence as Competitive Advantage**
- **Finding:** 93.23% on-time delivery with an average of 11 days ahead of schedule
- **Impact:** Strong operational capability that drives customer satisfaction
- **Insight:** On-time deliveries correlate with significantly higher review scores
- **Opportunity:** Leverage this strength in marketing; "Delivered Early or Your Money Back" guarantee

#### 3. **Geographic Revenue Concentration Risk**
- **Finding:** São Paulo region accounts for disproportionate share of revenue and sellers
- **Impact:** Over-reliance on single market creates vulnerability
- **Insight:** Other regions show demand but have limited seller/logistics infrastructure
- **Opportunity:** Expand seller network to underserved regions; potential $3-4M additional revenue

#### 4. **Health & Beauty Category Dominance**
- **Finding:** Health & Beauty leads with $1.45M (9.10% of revenue), followed by Watches & Gifts
- **Impact:** Top 10 categories drive 65% of revenue
- **Insight:** Category performance is stable but growth has plateaued
- **Opportunity:** 
  - Double down on winning categories with targeted marketing
  - Bundle products across complementary categories
  - Expand product selection in top performers

#### 5. **Payment Flexibility Drives Sales**
- **Finding:** 74% use credit cards with average 3-4 installments
- **Impact:** Installment plans enable higher-value purchases
- **Insight:** Low cancellation rate (0.63%) indicates payment processes work well
- **Opportunity:** Promote installment plans prominently; consider "Buy Now, Pay Later" for orders >$200

---

##  Business Recommendations

### Immediate Actions (0-3 Months)

####  Priority 1: Combat Customer Churn
**Problem:** 71.49% churn rate with 94% one-time customers

**Recommendations:**
1. **Launch Loyalty Program**
   - Points-based system: 1 point per $1 spent
   - Rewards: 10% discount after 3 orders, free shipping after 5 orders
   - **Expected Impact:** Increase repeat rate from 3% to 10-15%
   - **Revenue Impact:** +$2-3M annually

2. **Implement Email Re-engagement Campaign**
   - Segment customers by churn risk:
     - **At Risk (69%):** 20% discount + free shipping offer
     - **Warning (18%):** 10% discount on favorite categories
     - **Active (9%):** Exclusive new product previews
   - **Cadence:** Email 30, 60, 90 days post-purchase
   - **Expected Impact:** Recover 10-15% of at-risk customers

3. **Post-Purchase Engagement**
   - Send personalized product recommendations within 7 days
   - Request reviews with incentive (R$10 store credit)
   - Follow-up on products bought (e.g., "Need refills?")
   - **Expected Impact:** 5% increase in repeat purchases

**Investment:** R$150K - R$200K | **Expected ROI:** 300-400%

---

####  Priority 2: Leverage Delivery Excellence
**Strength:** 93.23% on-time delivery, avg 11 days ahead of schedule

**Recommendations:**
1. **Marketing Campaign: "Always On Time, Often Early"**
   - Highlight delivery performance in product pages
   - Add countdown timer showing "Likely to arrive X days early"
   - Create testimonial videos about fast delivery
   - **Expected Impact:** 15% increase in conversion rate

2. **Delivery Guarantee Program**
   - Promise: "If we don't deliver on time, get 20% off next order"
   - Risk is minimal with 93% on-time rate
   - Builds trust and differentiates from competitors
   - **Expected Impact:** Reduce cart abandonment by 10%

3. **Optimize Delivery Estimates**
   - Currently over-promising by 11 days
   - Adjust estimates to be more accurate but still achievable
   - Set expectations better: "Estimated: 18-22 days"
   - **Expected Impact:** Maintain high satisfaction, improve customer trust

**Investment:** R$50K marketing | **Expected ROI:** 250%

---

####  Priority 3: Expand Geographic Coverage
**Opportunity:** Underserved regions show demand but lack infrastructure

**Recommendations:**
1. **Seller Recruitment Program**
   - Target states with high order volume but few sellers:
     - **Rio de Janeiro** (RJ) - High demand, medium seller presence
     - **Bahia** (BA) - Growing market, limited supply
     - **Minas Gerais** (MG) - Strong potential, needs more sellers
   - Incentives: 
     - Waive seller fees for first 3 months
     - Free logistics training
     - Marketing support for new sellers
   - **Target:** Add 200 sellers in underserved regions
   - **Expected Impact:** $1-2M additional revenue

2. **Regional Fulfillment Centers**
   - Establish micro-warehouses in:
     - **North Region:** For AM, PA, RO states (worst delivery times)
     - **Northeast:** For BA, PE, CE states (high population, underserved)
   - Partner with local logistics providers
   - **Expected Impact:** Reduce delivery time by 5-7 days in target regions, increase sales by 20%

**Investment:** R$500K - R$800K | **Expected ROI:** 150-200% over 12 months

---

### Medium-Term Strategies (3-9 Months)

####  Category Optimization
1. **Double Down on Winners**
   - Expand product selection in top 5 categories
   - Recruit premium sellers in Health & Beauty, Watches
   - Create category-specific landing pages
   - **Expected Impact:** +15% revenue in top categories

2. **Cross-Category Bundling**
   - Bundle complementary categories: "Bed, Bath, Table" + "Housewares"
   - Offer 5-10% discount on bundles
   - Increase average order value
   - **Expected Impact:** AOV increase from $160 to $185

3. **Seasonal Campaign Planning**
   - Data shows Q4 peak - plan inventory and marketing 6 months ahead
   - Create promotional calendar aligned with Brazilian holidays
   - Pre-launch campaigns 60 days before peak seasons
   - **Expected Impact:** Smooth demand curve, increase Q4 revenue by 25%

####  Payment Innovation
1. **Promote Installment Plans**
   - Highlight "Pay in 4 installments" on high-value items
   - Test "Buy Now, Pay Later" for orders >$200
   - A/B test prominence of installment messaging
   - **Expected Impact:** 10% increase in conversion on orders >$150

2. **Expand Payment Options**
   - Add digital wallets (Pix, Mercado Pago)
   - Enable cryptocurrency for tech-savvy segment
   - Partner with fintech for credit pre-approval
   - **Expected Impact:** 5% increase in completed checkouts

####  Seller Quality Program
1. **Tiered Seller Badge System**
   - **Bronze:** 4.0+ rating, 50+ orders
   - **Silver:** 4.3+ rating, 200+ orders, <2% cancellation
   - **Gold:** 4.5+ rating, 500+ orders, 95%+ on-time
   - Promote top sellers with "Best Seller" badges
   - **Expected Impact:** Increase trust, 8% higher conversion on badge sellers

2. **Seller Performance Dashboard**
   - Give sellers real-time metrics
   - Benchmarking against category averages
   - Actionable recommendations for improvement
   - **Expected Impact:** Overall review score increase from 4.16 to 4.4

---

### Long-Term Vision (9-18 Months)

####  Platform Evolution
1. **Subscription Service**
   - Launch "Olist Prime" with benefits:
     - Free shipping on all orders
     - Exclusive deals
     - Early access to sales
   - Price: R$9.90/month or R$99/year
   - **Target:** Convert 10% of repeat customers (3K subscribers)
   - **Expected Revenue:** R$1.2M annually + increased order frequency

2. **Personalization Engine**
   - Implement AI/ML for product recommendations
   - Personalized homepage per user
   - Dynamic pricing based on customer segment
   - **Expected Impact:** 20% increase in conversion rate, 15% AOV lift

3. **Marketplace Expansion**
   - Services marketplace (repairs, installations)
   - Digital goods (courses, e-books)
   - B2B wholesale platform for small retailers
   - **Expected Impact:** 10-15% new revenue streams

####  International Expansion
1. **Test Markets**
   - Start with Spanish-speaking Latin America (Argentina, Chile)
   - Leverage existing logistics infrastructure
   - Partner with local sellers
   - **Expected Impact:** $5-8M revenue in year 1

---

##  Expected Business Impact

### Revenue Projections (12-Month Implementation)

| Initiative | Investment | Expected Revenue Impact | Timeframe |
|-----------|------------|------------------------|-----------|
| Loyalty Program | R$150K | +$2-3M | 6 months |
| Re-engagement Campaigns | R$50K | +$1-1.5M | 3 months |
| Delivery Marketing | R$50K | +$800K - $1M | 3 months |
| Geographic Expansion | R$600K | +$1-2M | 9 months |
| Category Optimization | R$100K | +$1.5-2M | 6 months |
| Payment Innovation | R$80K | +$600K | 6 months |
| **Total** | **R$1.03M** | **+$7.9M - $11.5M** | **12 months** |

### Key Performance Indicators (Target vs. Current)

| KPI | Current | 6-Month Target | 12-Month Target |
|-----|---------|---------------|-----------------|
| **Repeat Customer Rate** | 3% | 8% | 15% |
| **Churn Rate** | 71.49% | 60% | 45% |
| **Average Order Value** | $160 | $175 | $190 |
| **Customer Lifetime Value** | $165 | $285 | $450 |
| **Monthly Active Customers** | ~9K | ~15K | ~25K |
| **Review Score** | 4.16 | 4.3 | 4.5 |

---

##  How to Use This Project

### Prerequisites
- PostgreSQL 12+ installed
- Power BI Desktop (latest version)
- Dataset: [Olist Brazilian E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

### Step 1: Database Setup
```bash
# Create database
psql -U postgres
CREATE DATABASE olist_ecommerce;
\c olist_ecommerce

# Run schema creation
\i Create_Database.sql

# Run data cleaning
\i Data_cleaning.sql

# Run Power BI optimization
\i Power_BI_optimization.sql
```

### Step 2: Run Analysis Queries
Execute each analysis module in order:
1. `1_sales_performance_analysis.sql`
2. `2_customers_sales_and_churn.sql`
3. `3_delivery_and_logistics_analysis.sql`
4. `4_products_analysis.sql`
5. `5_payment_analysis.sql`
6. `6_sellers_analysis.sql`

### Step 3: Connect Power BI
1. Open Power BI Desktop
2. Get Data → PostgreSQL Database
3. Server: `localhost`
4. Database: `olist_ecommerce`
5. Import relevant tables and views
6. Build dashboards using provided visualizations as reference

### Step 4: Refresh & Analysis
- Set up scheduled refresh for real-time updates
- Customize dashboards for specific business needs
- Create additional drill-down reports as needed

---

## Skills Demonstrated

### Technical Skills
-  Advanced SQL (PostgreSQL)
  - Complex joins and subqueries
  - Window functions (LAG, LEAD, RANK, PERCENT_RANK)
  - Common Table Expressions (CTEs)
  - Date/time manipulation
  - Aggregation and grouping
-  Data Modeling & Schema Design
-  ETL & Data Cleaning
-  Power BI Dashboard Development
-  Data Visualization Best Practices
-  Database Optimization & Indexing

### Business Skills
-  Business Intelligence & Analytics
-  KPI Definition & Tracking
-  Customer Segmentation
-  Churn Analysis
-  Revenue Optimization
-  Strategic Recommendations
-  Data-Driven Decision Making

### Analytical Skills
-  Cohort Analysis
-  Trend Analysis & Forecasting
-  Correlation & Causation Analysis
-  A/B Testing Framework
-  Statistical Analysis
-  Performance Benchmarking

