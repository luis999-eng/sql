/* ASSIGNMENT 2 */
/* SECTION 2 */

-- COALESCE
/* 1. Our favourite manager wants a detailed long list of products, but is afraid of tables! 
We tell them, no problem! We can produce a list with all of the appropriate details. 

Using the following syntax you create our super cool and not at all needy manager a list:

SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product

But wait! The product table has some bad data (a few NULL values). 
Find the NULLs and then using COALESCE, replace the NULL with a 
blank for the first problem, and 'unit' for the second problem. 

HINT: keep the syntax the same, but edited the correct components with the string. 
The `||` values concatenate the columns into strings. 
Edit the appropriate columns -- you're making two edits -- and the NULL rows will be fixed. 
All the other rows will remain the same.) */

SELECT 
product_name || ', ' || coalesce(product_size,'')|| ' (' || coalesce(product_qty_type,'unit') || ')' as name_size_qty_type
FROM product;

--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

SELECT
customer_id,
full_name,
market_date,
dense_rank() OVER( PARTITION BY customer_id order by market_date) as visit_number_per_customer
FROM (SELECT DISTINCT 
cp.customer_id,
cp.market_date,
c.customer_first_name || ' ' || c.customer_last_name as full_name
FROM customer_purchases cp
join customer c
on cp.customer_id=c.customer_id) AS uv;



/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */


SELECT DISTINCT 
customer_id,
full_name,
market_date as most_recent,
visit_number_per_customer
FROM (SELECT
customer_id,
full_name,
market_date,
dense_rank() OVER( PARTITION BY customer_id order by market_date desc) as visit_number_per_customer
FROM (SELECT DISTINCT 
cp.customer_id,
cp.market_date,
c.customer_first_name || ' ' || c.customer_last_name as full_name
FROM customer_purchases cp
join customer c
on cp.customer_id=c.customer_id
Order by cp.market_date DESC) AS uv) as previous_query
where visit_number_per_customer=1;

/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */

SELECT 
product_id,
vendor_id,
market_date,
customer_id,
quantity,
cost_to_customer_per_qty,
transaction_time,
count(*) over( partition by customer_id, product_id) as count_customer_product
FROM customer_purchases cp;



-- String manipulations
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

SELECT 
product_name,
CASE WHEN instr(product_name,' - ') >0
	THEN trim(substr(product_name,instr(product_name,'-')+1))
	ELSE NULL
END AS	jar_organic
FROM	product p;


/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */

SELECT 
product_name,
product_size,
CASE WHEN instr(product_name,' - ') >0
	THEN trim(substr(product_name,instr(product_name,'-')+1))
	ELSE NULL
END AS	jar_organic
FROM	product p
WHERE product_size REGEXP '^\d+';

-- UNION
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day";
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

DROP TABLE IF EXISTS temp.daily_sales;

CREATE TEMP TABLE IF NOT EXISTS temp.daily_sales as
SELECT
market_date,
sum(quantity*cost_to_customer_per_qty) as sales
FROM customer_purchases cp
GROUP BY market_date;

SELECT 
market_date,
sales,
CASE
	WHEN sales = (SELECT MIN(sales) FROM temp.daily_sales) THEN 'min'
	WHEN sales = (SELECT MAX(sales) FROM temp.daily_sales) THEN 'max'
	ELSE NULL
END AS min_max
FROM temp.daily_sales
WHERE min_max NOTNULL;

--Forgot to use union - Code below with UNION (it was more complicated than the 1st i did )

DROP TABLE IF EXISTS temp.daily_sales2;

CREATE TEMP TABLE IF NOT EXISTS temp.daily_sales2 as
SELECT
market_date,
sum(quantity*cost_to_customer_per_qty) as sales
FROM customer_purchases cp
GROUP BY market_date;

DROP TABLE IF EXISTS temp.daily_rank_sales;

CREATE TEMP TABLE IF NOT EXISTS temp.daily_rank_sales as
SELECT *,
DENSE_RANK() OVER (ORDER BY sales DESC) as sales_rank_desc,
DENSE_RANK() OVER (ORDER BY sales ASC) as sales_rank_asc
FROM temp.daily_sales2;

SELECT market_date, sales,'Best_day' as label
FROM temp.daily_rank_sales 
WHERE sales_rank_desc = 1

UNION 

SELECT market_date, sales,'Worst_day' as label
FROM temp.daily_rank_sales
WHERE sales_rank_asc = 1;

/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */

--Price based on last product sold. Ex. Annies Pies lsat price to customer per qty was 18 * 5 * 26 customers = 2340. 

SELECT
sq.vendor_id,
v.vendor_name,
sq.product_id,
p.product_name,
sum(sq.max_cost * 5) as last_cost_times_5
FROM (
	SELECT vi.vendor_id,vi.product_id, max(cp.cost_to_customer_per_qty) as max_cost
	FROM vendor_inventory vi
	JOIN customer_purchases cp ON cp.vendor_id = vi.vendor_id 
	GROUP BY vi.vendor_id, vi.product_id) as sq
JOIN vendor v ON v.vendor_id=sq.vendor_id
JOIN product p ON p.product_id=sq.product_id 

CROSS JOIN 
(SELECT DISTINCT customer_id
FROM customer) as uc

GROUP BY sq.vendor_id,
v.vendor_name,
sq.product_id,
p.product_name;


-- INSERT
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

DROP TABLE IF EXISTS product_units;

CREATE TABLE product_units as 
SELECT *, CURRENT_TIMESTAMP as 'snapshot_timestamp'
FROM product
WHERE product_qty_type = 'unit';


/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */

INSERT INTO product_units
VALUES (24,'Luis Famous Butter Tart','large',2,'unit','2025-08-15 11:15:19');


-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/

DELETE FROM product_units
WHERE product_id = 24;

-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax. */


ALTER TABLE product_units
ADD current_quantity INT;

/*Then, using UPDATE, change the current_quantity equal to the last quantity value from the vendor_inventory details.

HINT: This one is pretty hard. 
First, determine how to get the "last" quantity per product. 
Second, coalesce null values to 0 (if you don't have null values, figure out how to rearrange your query so you do.) 
Third, SET current_quantity = (...your select statement...), remembering that WHERE can only accommodate one column. 
Finally, make sure you have a WHERE statement to update the right row, 
	you'll need to use product_units.product_id to refer to the correct row within the product_units table. 
When you have all of these components, you can run the update statement. */

-- first it will update base on the last vendor inventory count and change to 0 those who are not in the vendor inventory but there was record of the product on the product table, no more nulls
UPDATE product_units
SET current_quantity = COALESCE(test.quantity, 0)
FROM (
		SELECT pu.product_id, vi2.quantity
		FROM product_units pu
		LEFT JOIN(
			SELECT product_id, quantity 
			FROM (
				SELECT 
					vi.product_id, 
					vi.quantity,
					DENSE_RANK() OVER (PARTITION BY vi.product_id ORDER BY vi.market_date DESC) as order_product
				FROM vendor_inventory vi) ranked
			WHERE order_product=1 ) vi2
		ON pu.product_id = vi2.product_id
) as test
WHERE product_units.product_id = test.product_id;

