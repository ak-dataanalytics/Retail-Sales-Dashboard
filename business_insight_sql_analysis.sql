/* Dataset: 50K+ retail transaction records (2019–2022) across multiple regions, 
analyzed to identify revenue drivers, customer retention patterns, and month-over-month growth dynamics. */

use storesales

--previewing the data

select top 10* from sales

--checking null values
SELECT
SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer
FROM sales

--creating index 
CREATE INDEX idx_sales_customer
ON sales(customer_id);

--total revenue generated, total customers and total products

select round(sum(sales),2)as total_sales,
       count(distinct customer_id) as total_customer,
       count(distinct product_id) as total_products
from sales

--monthly revenue trend 

select month(order_date)as month_name,
round(sum(sales),2)as monthly_revenue
from sales
group by month(order_date)
order by month(order_date) asc

--month over month growth percentage 

WITH monthly_sales AS (
    SELECT 
        FORMAT(order_date, 'yyyy-MM') AS month,
        round(SUM(sales),2) AS revenue
    FROM sales
    GROUP BY FORMAT(order_date, 'yyyy-MM')
)
SELECT 
    month,
    revenue,
    round(LAG(revenue) OVER (ORDER BY month),2) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
        / LAG(revenue) OVER (ORDER BY month),
        2
    ) AS growth_percent
FROM monthly_sales;


--year in which the sales are recorded highest

select top 1
year(order_date)as year,
round(sum(sales),2) as total_revenue
from sales 
group by year(order_date)
order by total_revenue desc


--best quarter in terms of revenue 

SELECT 
    CONCAT(
        YEAR(order_date), 
        '-Q', 
        DATEPART(QUARTER, order_date)
    ) AS year_quarter,
    round(sum(sales),2) as quarterly_revenue
FROM sales
group by YEAR(order_date),DATEPART(QUARTER, order_date)
order by quarterly_revenue desc



-- top 10 customers based on revenue

select top 10
       customer_id,
       customer_name,
       round(sum(sales),2)as total_revenue
from sales 
group by customer_id, customer_name
order by total_revenue desc


--revenue comes from repeat customers as compared to one time customers

SELECT 
    CASE 
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'One-time'
    END AS customer_type,
    SUM(total_revenue) AS revenue,
    ROUND(
        SUM(total_revenue) * 100.0 
        / SUM(SUM(total_revenue)) OVER (),
        2
    ) AS revenue_percent
FROM (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(sales) AS total_revenue
    FROM sales
    GROUP BY customer_id
) AS customer_summary
GROUP BY 
    CASE 
        WHEN order_count > 1 THEN 'Repeat'
        ELSE 'One-time'
    END;



--average revenue per customer

select Round(
       sum(sales) / count(distinct customer_id) 
       , 2) as avg_revenue_per_cust
from sales 


--customers who placed more than one order 
 
 select count(customer_id) as no_of_cust
 from (
    select customer_id,
        count(distinct order_id)as order_count
from sales 
group by customer_id 
having count(order_id) > 1 )t


-- no and % of repeat customer and one time customer 

select 
    case
        when order_count > 1 then 'Repeat'
        else 'one_time'
        end as customer_type,
        count(*) as no_of_cust,
        round(count(*) * 100.0 /
        sum(count(*)) over (), 2)as percnt_customer
from (
select customer_id,
       count(distinct order_id) as order_count 
from sales 
group by customer_id 
)t
group by case
        when order_count > 1 then 'Repeat'
        else 'one_time'
        end 


--distribution of customers across region

select region,
       count(distinct customer_id)as customer_per_region
from sales 
group by region


-- percentage wise distribution across region

select region,
       customer_per_region,
       round(customer_per_region * 100.0 / 
       sum(customer_per_region) over (),2)as percnt
from (
select region,
       count(distinct customer_id)as customer_per_region
from sales 
group by region
)t 




--region wise total revenue and percentage

select region,
       total_revenue,
       round(total_revenue * 100.0 / total, 2) as revenue_percent
from (
select region,
       sum(sales) as total_revenue
from sales
group by region)t
cross join (select sum(sales)total from sales)a
order by revenue_percent desc



--product category that generates highest revenue

select top 1 with ties
       category,
       sum(sales) as revenue_generated
from sales 
group by category
order by revenue_generated desc


--sub-category that generates highest revenue

select top 1 with ties
       sub_category,
       sum(sales) as revenue_generated
from sales
group by sub_category
order by revenue_generated desc


-- Identified revenue concentration risk by analyzing top-performing products.

select top 5 with ties
       product_id,
       product_name,
       sum(sales) as revenue_generated
from sales
group by product_id, product_name
order by revenue_generated desc


-- Top 3 from each category based on revenue

select category,
       product_id,
       product_name, rnk
from (
select category,
       product_id,
       product_name,
      dense_rank() over (partition by category order by sum(sales) desc) as rnk
from sales 
group by category, product_id, product_name)t
where t.rnk <= 3


-- percentage of total revenue comes from TOP 10 products


SELECT ROUND(
       SUM(total_revenue) * 100.0 /
       (SELECT SUM(sales) FROM sales),
       2
) AS percnt
FROM (
    SELECT TOP 10 WITH TIES
           product_id,
           SUM(sales) AS total_revenue
    FROM sales
    GROUP BY product_id
    ORDER BY total_revenue DESC
) t;



--month over month revenue growth 

SELECT 
    year_month,
    revenue,
    LAG(revenue) OVER (ORDER BY year_month) AS prev_month_revenue,
    round(
    (revenue - LAG(revenue) OVER (ORDER BY year_month)) * 100.0 /
    LAG(revenue) OVER (ORDER BY year_month)
    ,2)as growth
FROM (
    SELECT 
        FORMAT(order_date, 'yyyy-MM') AS year_month,
        SUM(sales) AS revenue
    FROM sales
    GROUP BY FORMAT(order_date, 'yyyy-MM')
) t
order by growth desc


--year over year revenue growth 


SELECT 
    year_month,
    revenue,
    prev_year_revenue,
    ROUND(
        (revenue - prev_year_revenue) * 100.0 
        / prev_year_revenue,
        2
    ) AS growth
FROM (
    SELECT 
        year_month,
        revenue,
        LAG(revenue, 12) OVER (ORDER BY year_month) AS prev_year_revenue
    FROM (
        SELECT 
            FORMAT(order_date, 'yyyy-MM') AS year_month,
            SUM(sales) AS revenue
        FROM sales
        GROUP BY FORMAT(order_date, 'yyyy-MM')
    ) s
) t;



--cumulative total revenue and cumulative %

SELECT 
    year_month,
    revenue,
    cumulative_total,
    round(cumulative_total * 100.0 /
    total, 2) as cumulative_percent
from (
SELECT 
    year_month,
    revenue,
    sum(revenue) over (order by year_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)as cumulative_total
FROM (
    SELECT 
        FORMAT(order_date, 'yyyy-MM') AS year_month,
        SUM(sales) AS revenue
    FROM sales
    GROUP BY FORMAT(order_date, 'yyyy-MM')
) t )r
cross join (select sum(sales) as total from sales)a


     

--segmentation 


select 
                customer_id,
        total_revenue,
        cumulative_sales,
        cumulative_percent,
    case
        when cumulative_percent <= 70 then 'A'
        when cumulative_percent <= 90 then 'B'
        else 'C' end as customer_segment
from (
select customer_id,
       total_revenue,
       cumulative_sales,
       round(cumulative_sales *100.0 /
       total, 2) as cumulative_percent
from (
select customer_id,
       total_revenue,
       sum(total_revenue) over (order by total_revenue desc ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)as cumulative_sales
from (
select customer_id,
       sum(sales) as total_revenue
from sales 
group by customer_id)t )r
cross join (select sum(sales)as total from sales)s
)a


