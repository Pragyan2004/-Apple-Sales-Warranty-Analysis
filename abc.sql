CREATE TABLE stores (
    store_id INTEGER PRIMARY KEY,
    store_name TEXT,
    city TEXT,
    country TEXT
);

CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT
);

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT,
    category_id INTEGER,
    launch_date DATE,
    price INTEGER,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE sales (
    sale_id INTEGER PRIMARY KEY,
    sale_date DATE,
    store_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE warranty (
    claim_id INTEGER PRIMARY KEY,
    claim_date DATE,
    sale_id INTEGER,
    repair_status TEXT,
    FOREIGN KEY (sale_id) REFERENCES sales(sale_id)
);
select * from categories;
select * from products;
select * from sales;
select * from stores;
select * from warranty;

select distinct repair_status from warranty;
select count(*)  from sales;
explain analyze select * from sales
where product_id='P-44';

explain analyze SELECT * FROM sales WHERE product_id = 40;

SELECT country, COUNT(*) AS total_stores
FROM stores
GROUP BY country;

SELECT store_id, SUM(quantity) AS total_units_sold
FROM sales
GROUP BY store_id;

SELECT COUNT(*) AS sales_in_december
FROM sales
WHERE sale_date >= '2023-12-01' AND sale_date <= '2023-12-31';

SELECT COUNT(*) AS stores_without_claims
FROM stores
WHERE store_id NOT IN (
    SELECT DISTINCT s.store_id
    FROM sales s
    JOIN warranty w ON s.sale_id = w.sale_id
);

SELECT 
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE repair_status = 'Warranty Void') / COUNT(*),
    2
  ) AS percentage_void_claims
FROM warranty;

SELECT store_id, SUM(quantity) AS total_units
FROM sales
WHERE sale_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY store_id
ORDER BY total_units DESC
LIMIT 1;

SELECT COUNT(DISTINCT product_id) AS unique_products_sold
FROM sales
WHERE sale_date >= CURRENT_DATE - INTERVAL '1 year';

SELECT c.category_name, ROUND(AVG(p.price), 2) AS average_price
FROM products p
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_name;

SELECT COUNT(*) AS total_claims_2020
FROM warranty
WHERE claim_date BETWEEN '2020-01-01' AND '2020-12-31';

SELECT store_id, sale_date, daily_total
FROM (
    SELECT store_id, sale_date, SUM(quantity) AS daily_total,
           RANK() OVER (PARTITION BY store_id ORDER BY SUM(quantity) DESC) AS rk
    FROM sales
    GROUP BY store_id, sale_date
) ranked_sales
WHERE rk = 1;

SELECT *
FROM (
    SELECT 
        st.country,
        EXTRACT(YEAR FROM sa.sale_date) AS year,
        sa.product_id,
        SUM(sa.quantity) AS total_units,
        RANK() OVER (
            PARTITION BY st.country, EXTRACT(YEAR FROM sa.sale_date)
            ORDER BY SUM(sa.quantity) ASC
        ) AS rnk
    FROM sales sa
    JOIN stores st ON sa.store_id = st.store_id
    GROUP BY st.country, year, sa.product_id
) sub
WHERE rnk = 1;

SELECT COUNT(*) AS claims_within_180_days
FROM warranty w
JOIN sales s ON w.sale_id = s.sale_id
WHERE w.claim_date <= s.sale_date + INTERVAL '180 days';

SELECT COUNT(*) AS claims_for_recent_products
FROM warranty w
JOIN sales s ON w.sale_id = s.sale_id
JOIN products p ON s.product_id = p.product_id
WHERE p.launch_date >= CURRENT_DATE - INTERVAL '2 years';

SELECT c.category_name, COUNT(*) AS total_claims
FROM warranty w
JOIN sales s ON w.sale_id = s.sale_id
JOIN products p ON s.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
WHERE w.claim_date >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY c.category_name
ORDER BY total_claims DESC
LIMIT 1;

SELECT
    st.country,
    ROUND(100.0 * COUNT(DISTINCT w.sale_id) / COUNT(DISTINCT s.sale_id), 2) AS warranty_claim_percentage
FROM sales s
JOIN stores st ON s.store_id = st.store_id
LEFT JOIN warranty w ON s.sale_id = w.sale_id
GROUP BY st.country;

WITH yearly_sales AS (
    SELECT
        store_id,
        EXTRACT(YEAR FROM sale_date) AS year,
        SUM(quantity) AS total_units
    FROM sales
    GROUP BY store_id, year
),
growth_calc AS (
    SELECT
        store_id,
        year,
        total_units,
        LAG(total_units) OVER (PARTITION BY store_id ORDER BY year) AS previous_year_units
    FROM yearly_sales
)
SELECT
    store_id,
    year,
    total_units,
    previous_year_units,
    ROUND(
        100.0 * (total_units - previous_year_units) / NULLIF(previous_year_units, 0),
        2
    ) AS growth_percentage
FROM growth_calc;


WITH recent_sales AS (
    SELECT DISTINCT s.product_id, p.price
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    WHERE s.sale_date >= CURRENT_DATE - INTERVAL '5 years'
),
claims_per_product AS (
    SELECT s.product_id, COUNT(w.claim_id) AS warranty_claims
    FROM warranty w
    JOIN sales s ON w.sale_id = s.sale_id
    WHERE s.sale_date >= CURRENT_DATE - INTERVAL '5 years'
    GROUP BY s.product_id
),
price_claim_data AS (
    SELECT
        rs.price,
        cp.warranty_claims
    FROM recent_sales rs
    LEFT JOIN claims_per_product cp ON rs.product_id = cp.product_id
)
SELECT
    width_bucket(price, 0, 5000, 5) AS price_range_bucket,
    COUNT(*) AS product_count,
    SUM(COALESCE(warranty_claims, 0)) AS total_claims
FROM price_claim_data
GROUP BY price_range_bucket
ORDER BY price_range_bucket;

SELECT
    s.store_id,
    ROUND(100.0 * COUNT(*) FILTER (WHERE w.repair_status = 'Paid Repaired') / COUNT(*), 2) AS paid_repaired_percentage
FROM warranty w
JOIN sales s ON w.sale_id = s.sale_id
GROUP BY s.store_id
ORDER BY paid_repaired_percentage DESC
LIMIT 1;

WITH monthly_sales AS (
    SELECT
        store_id,
        DATE_TRUNC('month', sale_date) AS month,
        SUM(quantity) AS monthly_units
    FROM sales
    WHERE sale_date >= CURRENT_DATE - INTERVAL '4 years'
    GROUP BY store_id, month
),
running_totals AS (
    SELECT
        store_id,
        month,
        monthly_units,
        SUM(monthly_units) OVER (PARTITION BY store_id ORDER BY month) AS running_total
    FROM monthly_sales
)
SELECT *
FROM running_totals
ORDER BY store_id, month;