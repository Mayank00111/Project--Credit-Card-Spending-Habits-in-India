SELECT * FROM credit_card_transcations;

SELECT DISTINCT(city) FROM credit_card_transcations;   -- 986 row(s) returned
SELECT min(transaction_date) FROM credit_card_transcations; -- 1-Apr-14
SELECT DISTINCT(card_type) FROM credit_card_transcations;  -- Gold, Platinum, SIlver, Signature
SELECT DISTINCT(exp_type) FROM credit_card_transcations; -- Bills, Food, Entertainment, Grocery, Fuel, Travel

DESCRIBE credit_card_transcations;

-- 1. Write a query to print top 5 cities with highest spends and their percentage contribution of total credit card spends 
WITH CTE1 AS(SELECT city, SUM(amount) as city_wise_spend
FROM credit_card_transcations
GROUP BY city) 
,CTE2  AS ( SELECT SUM(amount) AS total_spend FROM credit_card_transcations)
SELECT  *, (100.0 * city_wise_spend/total_spend) as percentage_contribution
FROM 
CTE1, CTE2
ORDER BY city_wise_spend DESC
LIMIT 5;

-- 2. Write a query to print highest spend month and amount spent in that month for each card type.
SELECT * FROM credit_card_transcations;

SELECT MIN(transaction_date) , MAX(transaction_date)FROM credit_card_transcations;
-- NOT giving correct result because of transaction_date TEXT TYPE

SET SQL_SAFE_UPDATES = 0;

-- What I did to get this going is the following:
-- 1) Created a new column called date_transformed with the DATETIME format
-- 2) Run the following code:

ALTER TABLE credit_card_transcations ADD COLUMN trans_date datetime;

UPDATE credit_card_transcations
SET trans_date = str_to_date(transaction_date , "%m/%d/%y");

-- When you do this, MySQL will copy the date from one column to the other, transforming into a date formatted column. 
-- You can then rename the column as you wish and delete the old column you no longer need. I hope this helps.

SELECT * FROM credit_card_transcations;
SELECT MIN(trans_date) , MAX(trans_date)FROM credit_card_transcations;  --  04-10-2013 to 26-05-2015

-- 2. Write a query to print highest spend month and amount spent in that month for each card type

-- METHOD 1
WITH CTE1 AS(
SELECT card_type, YEAR(trans_date) as yr, MONTH(trans_date) as mnth,  SUM(amount) AS total_spend
FROM credit_card_transcations
GROUP BY card_type, YEAR(trans_date) , MONTH(trans_date) 
ORDER BY card_type, total_spend),
CTE2 AS (
SELECT card_type, max(total_spend) AS max_spend FROM CTE1 GROUP BY card_type)

SELECT CTE1.card_type, yr, mnth, max_spend
FROM CTE1 
INNER JOIN CTE2 ON CTE1.total_spend = CTE2.max_spend;

-- METHOD 2
WITH CTE AS(
SELECT card_type, YEAR(trans_date) as yr, MONTH(trans_date) as mnth,  SUM(amount) AS total_spend
FROM credit_card_transcations
GROUP BY card_type, YEAR(trans_date) , MONTH(trans_date) )
-- ORDER BY card_type, total_spend
SELECT * FROM
(SELECT *, RANK()  OVER (PARTITION BY card_type ORDER BY total_spend desc) AS rnk
FROM CTE) A 
WHERE rnk = 1;

-- 3- write a query to print the transaction details(all columns from the table) for each card type when
-- it reaches a cumulative of 1000000 total spends(We should have 4 rows in the output one for each card type)

SELECT * FROM credit_card_transcations;
-- THIS TIME WE HAVE TO THINK ABOUT CUMMULATIVE SUM THAT IS SUM BY EACH ROW

WITH CTE AS(
SELECT *, SUM(amount) OVER (PARTITION BY card_type ORDER BY trans_date, transaction_id) AS cumulative_sum 
FROM credit_card_transcations)

SELECT * FROM 
(SELECT *, RANK() OVER (PARTITION BY card_type ORDER BY cumulative_sum) AS rnk FROM CTE
WHERE  cumulative_sum > 1000000) A WHERE RNK = 1;

-- 4.  Write a query to find city which had lowest percentage spend for gold card type
WITH CTE AS (
SELECT city, card_type, sum(amount) AS city_wise_sum,
SUM(CASE WHEN card_type = 'Gold' THEN amount END) AS gold_amount
FROM credit_card_transcations
-- WHERE card_type = 'Gold'
GROUP BY city,card_type)

SELECT city, SUM(gold_amount) * 100.0 / city_wise_sum AS gold_ratio
FROM CTE
GROUP BY city
HAVING SUM(gold_amount) IS NOT NULL
ORDER BY gold_ratio;

-- 5. Write a query to print 3 columns:  city, highest_expense_type , lowest_expense_type (example format : Delhi , bills, Fuel)

SELECT * FROM credit_card_transcations;
SELECT DISTINCT(exp_type) FROM credit_card_transcations;

WITH CTE AS(
SELECT city, exp_type, SUM(amount) AS total_amount
FROM credit_card_transcations
GROUP BY city, exp_type 
ORDER BY city, total_amount)

SELECT city , MAX(CASE WHEN rnk_asc = 1 THEN exp_type END) AS lowest_expense_type,
MAX(CASE WHEN rnk_desc = 1 THEN exp_type END) AS highest_expense_type
FROM 
(SELECT *, RANK() OVER (PARTITION BY city ORDER BY total_amount desc) AS rnk_desc,
RANK() OVER (PARTITION BY city ORDER BY total_amount asc) AS rnk_asc
FROM CTE)  A
GROUP BY city;

-- 6. Write a query to find percentage contribution of spends by females for each expense type

SELECT * FROM credit_card_transcations;

-- METHOD 1
WITH CTE1 AS(
SELECT exp_type, gender, SUM(amount) AS agg_sum
FROM credit_card_transcations
GROUP BY gender, exp_type
ORDER BY  exp_type,gender)

SELECT exp_type, SUM(CASE WHEN gender = 'F' THEN agg_sum END ) * 1.0 / SUM(agg_sum) AS percentage_female_contribution
FROM  CTE1
GROUP BY exp_type;

-- METHOD 2
SELECT * FROM credit_card_transcations;

SELECT exp_type, 
SUM(CASE WHEN gender = 'F' THEN amount END ) * 1.0 / SUM(amount) AS percentage_female_contribution
FROM credit_card_transcations
GROUP BY exp_type;

-- 7. Which card and expense type combination saw highest month over month growth in Jan-2014

SELECT * FROM credit_card_transcations;

WITH CTE1 AS(
SELECT card_type, exp_type, YEAR(trans_date) AS yr, MONTH(trans_date) As mth, SUM(amount) AS month_wise_sale
FROM credit_card_transcations
GROUP BY card_type, exp_type, YEAR(trans_date), MONTH(trans_date))
, CTE2 AS ( SELECT *, LAG( month_wise_sale,1)  OVER (PARTITION BY card_type, exp_type ORDER BY yr, mth) AS previous_month_sale
FROM CTE1)
SELECT * , (month_wise_sale - previous_month_sale) * 1.0 / previous_month_sale AS mom_growth 
FROM CTE2
WHERE previous_month_sale IS NOT NULL AND yr = 2014 AND mth = 1
ORDER BY mom_growth DESC;

-- 9 During weekends which city has highest total spend to total no of transcations ratio
-- Highest spend/ total no of transactions in weelends

SELECT  *  FROM credit_card_transcations;
/*
query = """
SELECT 
    order_date,
    DATE_FORMAT(order_date, '%W') AS day_name, 
    DATE_FORMAT(order_date, '%a') AS abbreviated_day_name, 
    DATE_FORMAT(order_date, '%w') AS day_of_week,
    DATE_FORMAT(order_date, '%d') AS day_of_month,
    DATE_FORMAT(order_date, '%e') AS day_of_month_numeric,
    DATE_FORMAT(order_date, '%j') AS day_of_year
FROM order_items
"""
*/
SELECT 
    trans_date,
    DATE_FORMAT( trans_date, '%W') AS day_name, 
    DATE_FORMAT( trans_date, '%a') AS abbreviated_day_name, 
    DATE_FORMAT( trans_date, '%w') AS day_of_week,
    DATE_FORMAT( trans_date, '%d') AS day_of_month,
    DATE_FORMAT( trans_date, '%e') AS day_of_month_numeric,
    DATE_FORMAT( trans_date, '%j') AS day_of_year
FROM credit_card_transcations;

SELECT 
    trans_date,
    DATE_FORMAT(trans_date, '%M') AS month_name,
    DATE_FORMAT(trans_date, '%b') AS abbreviated_month_name,
    DATE_FORMAT(trans_date, '%m') AS month_number
FROM credit_card_transcations;

SELECT 
    city,
    SUM(amount) / COUNT(1) AS ratio
FROM credit_card_transcations
WHERE DATE_FORMAT( trans_date, '%w') IN (0,6)
GROUP BY city 
ORDER BY ratio desc;


-- 10. Which city took least number of days to reach its 500th transaction after the first transaction in that city
 SELECT * FROM credit_card_transcations;
 
 WITH CTE AS(
SELECT *,  RANK() OVER (PARTITION BY city ORDER BY trans_date, transaction_id) AS rnk
FROM credit_card_transcations)
SELECT city, DATEDIFF(max(trans_date), min(trans_date)) AS difference
FROM CTE
WHERE rnk = 1 OR rnk = 500
GROUP BY city
HAVING count(1) = 2
ORDER BY difference asc



 











