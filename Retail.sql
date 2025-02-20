create database RetailAnalysis;
use RetailAnalysis;
show tables;
select * from customer_profiles;
select * from product_inventory;
select * from sales_transaction;

/* Data Cleaning
Removal of duplicates
Fixing incorrect prices
Fixing null values
Cleaning date
*/

-- Removal of duplicates
select TransactionID, count(*) 
from sales_transaction
group by TransactionID
having count(*) >1;
create table st_noduplicates
as select distinct * from sales_transaction;
select TransactionID, count(*) 
from st_noduplicates
group by TransactionID
having count(*) >1;
-- This implies we have only one row per transaction ID. Duplicates Removed.

alter table st_noduplicates
rename to transactions;
select * from transactions;

-- Fixing Incorrect Prices
select p.ProductID,t.TransactionID,t.Price as trans_price,p.Price as prod_price
from transactions as t
join product_inventory as p on p.ProductID=t.ProductID
where t.Price<>p.Price;
-- Provides mismatched prices 
set sql_safe_updates=0;
update transactions as t
set Price=(select p.Price from product_inventory as p
where t.ProductID=p.ProductID)
where t.ProductID in (select p.ProductID from product_inventory as p 
where t.Price<>p.Price);
select p.ProductID,t.TransactionID,t.Price as trans_price,p.Price as prod_price
from transactions as t
join product_inventory as p on p.ProductID=t.ProductID
where t.Price<>p.Price;
-- No output implying that price discrepancy has been resolved.
select * from transactions where ProductID=51;

-- Fixing null values
select count(*) as count_nullvalues from customer_profiles
where Location=''; -- 13 null values
update customer_profiles
set Location="unknown"
where Location='';
select count(*) as count_nullvalues from customer_profiles
where Location='';
-- 0 as output implying no null values.

-- cleaning date
desc transactions; -- date is in text format
create table transactions_updated as
(select *,str_to_date(TransactionDate,'%d/%m/%Y') as DateUpdated from transactions);
desc transactions_updated;
alter table transactions_updated
drop column TransactionDate;
desc transactions_updated;
-- Date column has been updated.

-- exploratory data analysis
-- total sales and total quantity of every product
select t.ProductID as ProductID,p.ProductName as ProductName,round(sum(p.Price*t.QuantityPurchased),3) as total_sales,
sum(t.QuantityPurchased) as total_quantity
from transactions_updated as t
join product_inventory as p
on t.ProductID=p.ProductID
group by p.ProductID, p.ProductName
order by total_sales desc;

-- customer purchase frequency
-- customerid, count of transactions
select CustomerID, count(*) as number_of_transactions from transactions_updated
group by CustomerID
order by number_of_transactions desc;

-- product category performance on the basis of total sales
select p.Category,round(sum(t.QuantityPurchased*t.Price),3) as total_sales , sum(t.QuantityPurchased) as total_units_sold
from transactions_updated as t
join product_inventory as p
on t.ProductID=p.ProductID
group by p.Category
order by total_sales desc;

-- top 10 high sales and low sale product
select ProductID, round(sum(Price*QuantityPurchased),3) as total_revenue_sales
from transactions_updated
group by ProductID
order BY total_revenue_sales desc
limit 10;

select ProductID, round(sum(Price*QuantityPurchased),3) as total_revenue_sales
from transactions_updated
group by ProductID
order BY total_revenue_sales
limit 10;

-- to identify the sales trend- revenue pattern of the organization starting from the earliest date till the last date of this table
select DateUpdated as Date_of_Transaction, count(*) as Trans_count, sum(QuantityPurchased) as tqs,
round(sum(QuantityPurchased*Price),3) as total_revenue_sales 
from transactions_updated
group by Date_of_Transaction
order by Date_of_Transaction;

-- what is the month on month growth? 
-- growth_mom =((current month sales−previous month sales)/previous month sales)×100
with monthly_sales as(
select month(DateUpdated) as month_name,
round(sum(QuantityPurchased*Price),3) as total_sales
from transactions_updated
group by month_name
)
select month_name,total_sales,
lag(total_sales) over(order by month_name) as prev_month_sales,
round(((total_sales - lag(total_sales) over(order by month_name))/lag(total_sales) over(order by month_name))*100,2) as growth_mom
from monthly_sales
order by month_name;

-- high purchase frequency
-- cid, no of transactions, totalspent
select CustomerID,count(*) as no_transactions,round(sum(QuantityPurchased*Price),3) as total_spent
from transactions_updated
group by CustomerID
order by total_spent desc;

-- occasional customers-(no of transactions<=2)
-- cid, count of transactions, total amount spent
select CustomerID, count(TransactionID) as num_trans,
round(sum(QuantityPurchased*Price),3) as total_amount_spent
from transactions_updated
group by CustomerID
having num_trans<=2
order by num_trans, total_amount_spent desc;
 
 -- repeat purchases
 select CustomerID,ProductID, count(*) as num_purchased
from transactions_updated
group by CustomerID,ProductID
having num_purchased>=1
order by num_purchased desc;

-- loyalty indicators
select CustomerID, min(DateUpdated) as first_purchase,max(DateUpdated) as last_purchase,
datediff(max(DateUpdated),min(DateUpdated)) as Days_between_Purchases
from transactions_updated
group by CustomerID
having Days_between_Purchases>0
order by Days_between_Purchases desc;

/* customer segmentation
0 - no orders
1-10 -low
10-30 -middle
>30 -high */
alter table customer_profiles
change column ï»¿CustomerID CustomerID int;
desc customer_profiles;

create table customer_segment as
select CustomerID,
case when total_quantity>30 then "High"
when total_quantity between 10 and 30 then "Mid"
when total_quantity between 1 and 10 then "Low"
else "No Orders"
end as Customer_Segments
from (
select c.CustomerID, sum(t.QuantityPurchased) as total_quantity
from customer_profiles as c
join transactions_updated as t
on c.CustomerID=t.CustomerID
group by c.CustomerID
) as derived_table;
select * from customer_segment;
select Customer_Segments, count(*) as Count
from customer_segment
group by Customer_Segments;