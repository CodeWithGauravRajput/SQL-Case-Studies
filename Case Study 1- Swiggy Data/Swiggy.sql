-- ====================================================
-- Swiggy SQL Case Study
-- ====================================================

-- 1) Find customers who have never ordered
SELECT  * FROM users
WHERE user_id NOT IN (SELECT DISTINCT(user_id) FROM orders);

-- 📘 Findings / Learnings:
-- - Works if orders.user_id has no NULLs.
-- - Safer alternative: LEFT JOIN with IS NULL check.
-- - Helps identify inactive users for targeted campaigns.

-- 2) Average Price/dish
SELECT AVG(price) FROM menu;

-- 📘 Findings / Learnings:
-- - Simple aggregation using AVG().
-- - Returns NULL if table is empty.
-- - Helps understand typical dish pricing.

-- 3) Distinct months in orders
SELECT DISTINCT(MONTHNAME(date)) FROM orders;

-- 📘 Findings / Learnings:
-- - MONTHNAME sorts alphabetically, not chronologically.
-- - Use YEAR(date) + MONTH(date) for correct timeline.
-- - Helps understand order distribution over months.

-- 4) Top 1 restaurant in terms of number of orders for every month
WITH t AS (
    SELECT r_id, COUNT(r_id) AS total_orders, MONTHNAME(date) AS order_month
    FROM orders
    GROUP BY r_id, MONTHNAME(date)
    ORDER BY COUNT(r_id) DESC
)
SELECT t.r_id,
       r.r_name,
       t.total_orders,
       t.order_month 
FROM t
JOIN restaurants AS r ON t.r_id = r.r_id
ORDER BY t.total_orders DESC
LIMIT 3;

-- 📘 Findings / Learnings:
-- - Shows top 3 overall, not per month.
-- - To get top per month: use ROW_NUMBER()/RANK() partitioned by month.
-- - Useful for identifying popular restaurants each month.

-- 5) Top restaurant in a given month
SELECT r_id, COUNT(r_id) AS total_orders, MONTHNAME(date)  
FROM orders  
GROUP BY r_id, MONTHNAME(date)
ORDER BY total_orders DESC
LIMIT 5;	

-- 📘 Findings / Learnings:
-- - No explicit month filter; may mix multiple months.
-- - Add YEAR(date) and MONTH(date) filter for a specific month.
-- - Helps find highest-demand restaurants in a month.

-- 6) Top restaurant overall
WITH t1 AS (
    SELECT r_id, COUNT(r_id) AS total_orders 
    FROM orders
    GROUP BY r_id
)	
SELECT r_name, total_orders 
FROM restaurants AS r
JOIN t1 ON r.r_id = t1.r_id 
ORDER BY total_orders DESC
LIMIT 1;

-- 📘 Findings / Learnings:
-- - Correct for overall top restaurant.
-- - LIMIT 1 ignores ties; use RANK() for multiple top restaurants.

-- 7) Restaurants with monthly sales > X
WITH t AS(
    SELECT r_id, MONTHNAME(date) AS months, SUM(amount) AS total_sales
    FROM orders
    GROUP BY r_id, MONTHNAME(date)
)
SELECT DISTINCT(r.r_name)
FROM t 
JOIN restaurants AS r ON r.r_id = t.r_id 
WHERE total_sales > 1100;

-- 📘 Findings / Learnings:
-- - Correct logic, but month info not shown.
-- - Include YEAR(date) for proper time breakdown.
-- - Helps identify high-performing restaurants per month.

-- 8) Show all orders with order details for a particular customer in a date range
SELECT * FROM orders AS o 
JOIN order_details AS od ON o.order_id = od.order_id
JOIN users AS u ON u.user_id = o.user_id
WHERE (o.user_id = 3) AND (o.date BETWEEN '2022-05-01' AND '2022-05-31');

-- 📘 Findings / Learnings:
-- - Works correctly for filtering customer orders in a specific date range.
-- - Indexing (user_id, date) improves performance.
-- - Useful for user-specific order history.

-- 9) Restaurants with max repeated customers
WITH t AS (
    SELECT r_id, user_id, COUNT(r_id) AS repeat_cus  
    FROM orders
    GROUP BY r_id, user_id
    HAVING COUNT(r_id) > 1
)
SELECT r.r_name AS restaurant_name, u.name AS customer, t.repeat_cus
FROM t
JOIN restaurants AS r ON t.r_id = r.r_id
JOIN users AS u ON u.user_id = t.user_id;

-- 📘 Findings / Learnings:
-- - Finds customers who repeatedly order from the same restaurant.
-- - Useful for loyalty analysis and retention strategies.

-- 10) Month over month revenue growth of Swiggy
SELECT YEAR(date) AS yr, MONTHNAME(date), SUM(amount),
       SUM(amount) - LAG(SUM(amount)) OVER() 
FROM orders
GROUP BY YEAR(date), MONTHNAME(date);

-- 📘 Findings / Learnings:
-- - LAG() syntax may fail; should include ORDER BY in window function.
-- - MONTHNAME alone sorts alphabetically; use YEAR + MONTH for correct sequence.
-- - Helps monitor revenue growth trends.

-- 11) Customer → favorite food
WITH z AS (
    WITH t AS (
        SELECT o.order_id, u.name, f.f_name, o.amount 
        FROM orders AS o
        JOIN order_details AS od ON o.order_id = od.order_id
        JOIN food AS f ON od.f_id = f.f_id
        JOIN users AS u ON o.user_id = u.user_id
    )
    SELECT *, COUNT(f_name) OVER(PARTITION BY name, f_name) AS f_count
    FROM t
)
SELECT * FROM (
    SELECT *, DENSE_RANK() OVER(PARTITION BY name ORDER BY f_count DESC) AS rn
    FROM z
) AS x
WHERE x.rn = 1;

-- 📘 Findings / Learnings:
-- - Correctly finds most frequently ordered food per customer.
-- - DENSE_RANK ensures ties are handled.
-- - Useful for personalizing recommendations.

-- 12) Most loyal customers of all restaurants
WITH x AS (
    SELECT o.r_id, r.r_name, u.name, COUNT(DISTINCT o.order_id) AS ord_count  
    FROM orders AS o
    JOIN order_details AS od ON o.order_id = od.order_id
    JOIN users AS u ON o.user_id = u.user_id
    JOIN restaurants AS r ON o.r_id = r.r_id
    GROUP BY o.r_id, r.r_name, u.name 
)
SELECT * FROM (
    SELECT *, MAX(ord_count) OVER(PARTITION BY r_name) AS max_ord_count 
    FROM x
) AS rxng
WHERE rxng.ord_count = max_ord_count
ORDER BY r_id;

-- 📘 Findings / Learnings:
-- - Finds the most loyal customer(s) per restaurant.
-- - Handles ties automatically.
-- - Useful for loyalty programs and rewards.

-- 13) Month over month revenue growth of a restaurant
WITH t1 AS (
    SELECT r.r_id, r.r_name, MONTHNAME(o.date) AS months, SUM(o.amount) AS total_revenue
    FROM orders AS o 
    JOIN restaurants AS r ON o.r_id = r.r_id
    GROUP BY r.r_id, MONTHNAME(o.date), r.r_name
    ORDER BY r.r_id, MONTHNAME(o.date) DESC
)
SELECT *, LAG(total_revenue) OVER(PARTITION BY r_id) AS cal,
       (total_revenue - LAG(total_revenue) OVER(PARTITION BY r_id)) AS month_by_month_revenue_growth
FROM t1;

-- 📘 Findings / Learnings:
-- - LAG() used to calculate growth compared to previous month.
-- - MONTHNAME sorts alphabetically; include YEAR + MONTH for proper chronological growth.
-- - Helps restaurants track monthly revenue changes.

-- ====================================================
-- End of Swiggy SQL Case Study
-- ====================================================


-- 📌 Conclusion
-- Your SQL case study covers a wide range of business questions: customer segmentation, restaurant performance, sales growth, favorites, and item pairing. Most queries are logically correct, but a few need adjustments for time-series analysis (use YEAR(date) + MONTH(date) instead of MONTHNAME()) and ranking per group (use ROW_NUMBER()/RANK() instead of LIMIT).
-- The exercise demonstrates:
-- Customer analytics: inactive customers, loyal customers, favorite foods.
-- Restaurant analytics: top restaurants overall, by month, by sales.
-- Revenue analysis: MoM growth for company and restaurants.
-- Product analytics: average price, co-occurrence of dishes (to be added).
-- Overall, this file is a solid SQL case study project for GitHub. It shows skills in joins, aggregations, window functions, and business-oriented SQL.
