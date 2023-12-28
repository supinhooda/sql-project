select * from final_table;

-- R1: Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
select distinct(market) from dim_customer

where customer="Atliq Exclusive" and
region="APAC";

-- Q2 What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields
-- unique_products_2020
-- unique_products_2021
-- percentage_chg


with 
cte20 as
(select count(distinct(product_code)) as unique_products_2020
from fact_manufacturing_cost as f 
where cost_year=2020),
cte21 as
(select count(distinct(product_code)) as unique_products_2021
from fact_manufacturing_cost as f 
where cost_year=2021)

select *,
		round((unique_products_2021-unique_products_2020)*100/unique_products_2020,2) as percentage_chg		
from cte20
cross join
cte21;

-- Q3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
-- The final output contains 2 fields, 
-- segment 
-- product_count

select 
	segment,
	count(distinct(product_code)) as product_count
from dim_product
group by segment
order by product_count desc;

-- Q4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields, 
-- segment 
-- product_count_2020 
-- product_count_2021 
-- difference
with

cte20 as
(select 
	p.segment,
    count(distinct(f.product_code)) as product_count_2020		
from fact_sales_monthly as f
join 
	dim_product as p
using(product_code)
where fiscal_year=2020
group by segment
order by product_count_2020 desc
),
cte21 as
(select
		p.segment,
        count(distinct(f.product_code)) as product_count_2021

from fact_sales_monthly as f
join 
	dim_product as p
using(product_code)
where fiscal_year=2021
group by segment
order by product_count_2021 desc),

cte_table as 
(select 
	cte20.segment,
    product_count_2021,
    product_count_2020,
    (product_count_2021-product_count_2020) as difference
		
from cte20
join cte21
using(segment)
)

select
	segment,
    product_count_2021,
    product_count_2020,
    difference
from cte_table
where 
	difference=(select max(difference) from cte_table);

-- Q5. Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, 
-- product_code 
-- product 
-- manufacturing_cost
select 
	p.product_code,
	p.product,
	m.manufacturing_cost
from dim_product as p
join fact_manufacturing_cost as m
using(product_code)
where 
	manufacturing_cost=(select max(manufacturing_cost) from fact_manufacturing_cost) or 
	manufacturing_cost=(select min(manufacturing_cost) from fact_manufacturing_cost)
order by manufacturing_cost desc;

-- Q6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
-- The final output contains these fields, 
-- customer_code 
-- customer 
-- average_discount_percentage
set sql_mode="";
SELECT
	d.customer_code,
    c.customer,
    CONCAT(ROUND(AVG(d.pre_invoice_discount_pct)*100,2),"%") as average_discount_percentage
FROM dim_customer as c
JOIN fact_pre_invoice_deductions as d
USING(customer_code)
WHERE fiscal_year=2021 AND market="India"
GROUP BY d.customer_code
ORDER BY AVG(d.pre_invoice_discount_pct) DESC
LIMIT 5;

-- Alternative-- Not Recomended(Below)--Check above one--More efficient--(Below only for PRACTICE)
with cte as(
select
	s.customer_code,
    c.customer,
    round((avg(p.pre_invoice_discount_pct)*100),2) as average_discount_percentage

from fact_sales_monthly as s
join fact_pre_invoice_deductions as p
on
	s.customer_code=p.customer_code and 
    s.fiscal_year=p.fiscal_year
join dim_customer as c
on
	s.customer_code=c.customer_code

where
	s.fiscal_year=2021 and
    c.market="India"

group by s.customer_code,c.customer
order by average_discount_percentage desc),

rank_table as (
select 
	*,
    row_number() over(order by average_discount_percentage desc) as rn,
    rank() over(order by average_discount_percentage desc) as rk,
    dense_rank() over(order by average_discount_percentage desc) as drk
from cte)

select
	customer_code,
    customer,
    average_discount_percentage
from rank_table
where drk<=5;

-- Q7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
-- The final report contains these columns: 
-- Month 
-- Year 
-- Gross sales Amount

select
    i.month_name as Month,
    Year(s.date) as Year,
    round(sum(g.gross_price*s.sold_quantity)/1000000,2) as gross_sales_price
from fact_gross_price as g
join fact_sales_monthly as s
on 
	s.product_code=g.product_code and
    s.fiscal_year=g.fiscal_year
join dim_customer as c
on
	s.customer_code=c.customer_code
join month_info as i
on
	i.month_number=month(s.date)
where
	customer="Atliq Exclusive"

group by date
order by date,gross_sales_price desc;

-- Q8. In which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity,
-- Quarter 
-- total_sold_quantity

with cte as(
select 
	*,
	case
		when month(s.date) in (9,10,11) then "Q1"
        when month(s.date) in (12,1,2) then "Q2"
        when month(s.date) in (3,4,5) then "Q3"
        else "Q4"
	end as Quarter
from fact_sales_monthly as s
where fiscal_year=2020
)
select 
	Quarter,
    sum(sold_quantity) as total_sold_quantity
from cte
group by Quarter
order by total_sold_quantity desc;

-- Q9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields, 
-- channel 
-- gross_sales_mln 
-- percentage

with cte as(
select
    c.channel,
    round(sum(s.sold_quantity*g.gross_price)/1000000,2) as gross_sales_mln
from dim_customer as c
join fact_sales_monthly as s
on
	c.customer_code=s.customer_code
join fact_gross_price as g
on
	g.product_code=s.product_code and
    g.fiscal_year=s.fiscal_year

where s.fiscal_year=2021
group by channel
order by gross_sales_mln desc)

select
	*,
    CONCAT(round(gross_sales_mln*100/sum(gross_sales_mln) over(),2),"%")as percentage
from cte;

-- Q10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these fields, 
-- division 
-- product_code

with cte as(
select
	p.division,
    p.product,
    p.variant,
    p.product_code,
    sum(s.sold_quantity) as total_qty
from dim_product as p
join fact_sales_monthly as s
on
	p.product_code=s.product_code
where 
	s.fiscal_year=2021
    
group by division,product_code
order by total_qty desc),
cte1 as(
select 
	*,
    dense_rank() over(partition by division order by total_qty desc) as drank
from cte)
select
	division,
    concat(product," ",variant) product_variant,
    product_code,
    total_qty
from cte1
where drank<=3;


	







