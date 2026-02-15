-- Creating table for customer data for Olist E-commerce dataset
CREATE DATABASE olist_ecommerce;
-- 1. Customers table
CREATE TABLE customers (
    customer_id VARCHAR(255) PRIMARY KEY,
    customer_unique_id VARCHAR(255),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(255),
    customer_state VARCHAR(2)
);

-- 2. Geolocation table
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat DECIMAL(10, 8),
    geolocation_lng DECIMAL(11, 8),
    geolocation_city VARCHAR(255),
    geolocation_state VARCHAR(2)
);

-- 3. Order items table
CREATE TABLE order_items (
    order_id VARCHAR(255),
    order_item_id INTEGER,
    product_id VARCHAR(255),
    seller_id VARCHAR(255),
    shipping_limit_date TIMESTAMP,
    price DECIMAL(10, 2),
    freight_value DECIMAL(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 4. Order payments table
CREATE TABLE order_payments (
    order_id VARCHAR(255),
    payment_sequential INTEGER,
    payment_type VARCHAR(50),
    payment_installments INTEGER,
    payment_value DECIMAL(10, 2)
);

-- 5. Order reviews table
CREATE TABLE order_reviews (
    review_id VARCHAR(255),
    order_id VARCHAR(255),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- 6. Orders table
CREATE TABLE orders (
    order_id VARCHAR(255) PRIMARY KEY,
    customer_id VARCHAR(255),
    order_status VARCHAR(50),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);


-- 7. Products table
CREATE TABLE products (
    product_id VARCHAR(255) PRIMARY KEY,
    product_category_name VARCHAR(255),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);

-- 8. Sellers table
CREATE TABLE sellers (
    seller_id VARCHAR(255) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(255),
    seller_state VARCHAR(2)
);


-- 9. Product category name translation (if available)
CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(255) PRIMARY KEY,
    product_category_name_english VARCHAR(255)
);

-- Add foreign key constraints
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customer
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_order
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_product
FOREIGN KEY (product_id) REFERENCES products(product_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_seller
FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);

ALTER TABLE order_payments
ADD CONSTRAINT fk_order_payments_order
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_reviews
ADD CONSTRAINT fk_order_reviews_order
FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- Create indexes for better query performance
CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_seller_id ON order_items(seller_id);
CREATE INDEX idx_geolocation_zip ON geolocation(geolocation_zip_code_prefix);


-- Import data
-- First, import tables WITHOUT foreign key dependencies
COPY customers FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_customers_dataset.csv' DELIMITER ',' CSV HEADER;
COPY products FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_products_dataset.csv' DELIMITER ',' CSV HEADER;
COPY sellers FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_sellers_dataset.csv' DELIMITER ',' CSV HEADER;
COPY geolocation FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_geolocation_dataset.csv' DELIMITER ',' CSV HEADER;
COPY product_category_name_translation FROM 'D:\Final_projects\e-commerce_data\csv.data/product_category_name_translation.csv' DELIMITER ',' CSV HEADER;
-- Then import orders (references customers)
COPY orders FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_orders_dataset.csv' DELIMITER ',' CSV HEADER;

-- Finally import tables that reference orders
COPY order_items FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_order_items_dataset.csv' DELIMITER ',' CSV HEADER;
COPY order_payments FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_order_payments_dataset.csv' DELIMITER ',' CSV HEADER;
COPY order_reviews FROM 'D:\Final_projects\e-commerce_data\csv.data/olist_order_reviews_dataset.csv' DELIMITER ',' CSV HEADER;

SELECT *
FROM order_items