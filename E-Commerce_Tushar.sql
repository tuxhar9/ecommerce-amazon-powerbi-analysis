use ecommerce_db;

## Q14 Identify the top 5 most valuable customers using a composite score that combines three key metrics: (SQL)
# a) Total Revenue (50% weight): The total amount of money spent by the customer.

SELECT
    CustomerID,
    SUM(`Sale Price`) AS TotalRevenue
FROM ecommerce_db.ecommerce_dataset_c
GROUP BY CustomerID
ORDER BY TotalRevenue DESC
LIMIT 5;

# b) Order Frequency (30% weight): The number of orders placed by the customer, indicating their loyalty and engagement.

SELECT
    CustomerID,
    COUNT(OrderID) AS OrderCount
FROM ecommerce_db.ecommerce_dataset_c
GROUP BY CustomerID
ORDER BY OrderCount DESC
LIMIT 5;
# c) Average Order Value (20% weight): The average value of each order placed by the customer, reflecting the typical transaction size.

SELECT
    CustomerID,
    AVG(`Sale Price`) AS AvgOrderValue
FROM ecommerce_db.ecommerce_dataset_c
GROUP BY CustomerID
ORDER BY AvgOrderValue DESC
LIMIT 5;

# Final Combine Query (a+b+c)

WITH customer_metrics AS (
    SELECT
        CustomerID,
        SUM(`Sale Price`) AS TotalRevenue,        -- (a) 50% weight
        COUNT(OrderID) AS OrderCount,               -- (b) 30% weight
        AVG(`Sale Price`) AS AvgOrderValue          -- (c) 20% weight
    FROM ecommerce_db.ecommerce_dataset_c
    GROUP BY CustomerID
),
max_values AS (
    SELECT
        MAX(TotalRevenue) AS MaxRevenue,
        MAX(OrderCount) AS MaxOrderCount,
        MAX(AvgOrderValue) AS MaxAvgValue
    FROM customer_metrics
)
SELECT
    cm.CustomerID,
    cm.TotalRevenue,
    cm.OrderCount,
    cm.AvgOrderValue,
    ROUND(
        (0.5 * (cm.TotalRevenue / mv.MaxRevenue)) +
        (0.3 * (cm.OrderCount / mv.MaxOrderCount)) +
        (0.2 * (cm.AvgOrderValue / mv.MaxAvgValue)),
        4
    ) AS CompositeScore
FROM customer_metrics cm
CROSS JOIN max_values mv
ORDER BY CompositeScore DESC
LIMIT 5;

## Q15 Calculate the month-over-month growth rate in total revenue across the entire dataset. (SQL)

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(STR_TO_DATE(OrderDate, '%e/%c/%Y'), '%Y-%m') AS YearMonth,
        SUM(`Sale Price`) AS TotalRevenue
    FROM ecommerce_db.ecommerce_dataset_c
    GROUP BY DATE_FORMAT(STR_TO_DATE(OrderDate, '%e/%c/%Y'), '%Y-%m')
),
growth_calc AS (
    SELECT
        YearMonth,
        TotalRevenue,
        LAG(TotalRevenue) OVER (ORDER BY YearMonth) AS PrevMonthRevenue
    FROM monthly_revenue
)
SELECT
    YearMonth, TotalRevenue, PrevMonthRevenue,
    ROUND(((TotalRevenue - PrevMonthRevenue) / PrevMonthRevenue) * 100, 2) AS MoM_Growth_Percent
FROM growth_calc
WHERE PrevMonthRevenue IS NOT NULL
ORDER BY YearMonth;

## Q16- Calculate the rolling 3-month average revenue for each product category. (SQL)

WITH revenue_by_month_category AS (
    SELECT
        DATE_FORMAT(STR_TO_DATE(OrderDate, '%e/%c/%Y'), '%Y-%m') AS YearMonth,
        `Product Category` AS ProductCategory,
        SUM(`Sale Price`) AS MonthlyRevenue
    FROM ecommerce_db.ecommerce_dataset_c
    GROUP BY
        DATE_FORMAT(STR_TO_DATE(OrderDate, '%e/%c/%Y'), '%Y-%m'),
        `Product Category`
),
rolling_avg_calc AS (
    SELECT
        YearMonth, ProductCategory, MonthlyRevenue,
        ROUND(
            AVG(MonthlyRevenue) OVER (
                PARTITION BY ProductCategory
                ORDER BY YearMonth
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 2
        ) AS Rolling_3_Month_Avg
    FROM revenue_by_month_category
)
SELECT * FROM rolling_avg_calc
ORDER BY ProductCategory, YearMonth;

## Q17- Update the orders table to apply a 15% discount on the `Sale Price` for orders placed by customers who have made at least 10 orders. (SQL)

UPDATE ecommerce_db.ecommerce_dataset_c
SET `Sale Price` = `Sale Price` * 0.85
WHERE CustomerID IN (
    SELECT CustomerID
    FROM (
        SELECT CustomerID
        FROM ecommerce_db.ecommerce_dataset_c
        GROUP BY CustomerID
        HAVING COUNT(*) >= 10
    ) AS eligible_customers
);

SELECT MAX(order_count) AS MaxOrdersByAnyCustomer
FROM (
    SELECT CustomerID, COUNT(*) AS order_count
    FROM ecommerce_db.ecommerce_dataset_c
    GROUP BY CustomerID
) AS customer_order_counts;

## Q18- Calculate the average number of days between consecutive orders for customers who have placed at least five orders. (SQL)

WITH order_gaps AS (
    SELECT
        CustomerID,
        DATEDIFF(
            STR_TO_DATE(OrderDate, '%e/%c/%Y'),
            LAG(STR_TO_DATE(OrderDate, '%e/%c/%Y')) OVER (
                PARTITION BY CustomerID
                ORDER BY STR_TO_DATE(OrderDate, '%e/%c/%Y')
            )
        ) AS DaysBetweenOrders
    FROM ecommerce_db.ecommerce_dataset_c
),
qualified_customers AS (
    SELECT CustomerID
    FROM ecommerce_db.ecommerce_dataset_c
    GROUP BY CustomerID
    HAVING COUNT(*) >= 5
)
SELECT
    og.CustomerID,
    ROUND(AVG(og.DaysBetweenOrders), 2) AS Avg_Days_Between_Orders
FROM order_gaps og
JOIN qualified_customers qc ON og.CustomerID = qc.CustomerID
WHERE og.DaysBetweenOrders IS NOT NULL
GROUP BY og.CustomerID
ORDER BY Avg_Days_Between_Orders;

## Q19- Identify customers who have generated revenue that is more than 30% higher than the average revenue per customer. (SQL)

WITH customer_revenue AS (
    SELECT CustomerID, SUM(`Sale Price`) AS TotalRevenue
    FROM ecommerce_db.ecommerce_dataset_c
    WHERE Status = 'Delivered'
    GROUP BY CustomerID
),
average_revenue AS (
    SELECT AVG(TotalRevenue) AS AvgRevenue FROM customer_revenue
)
SELECT cr.CustomerID, cr.TotalRevenue
FROM customer_revenue cr
JOIN average_revenue ar ON 1 = 1
WHERE cr.TotalRevenue > ar.AvgRevenue * 1.3
ORDER BY cr.TotalRevenue DESC;

## Q20- Determine the top 3 product categories that have shown the highest increase in sales over the past year compared to the previous year. (SQL)

WITH formatted_sales AS (
    SELECT
        `Product Category` AS ProductCategory,
        YEAR(STR_TO_DATE(OrderDate, '%e/%c/%Y')) AS OrderYear,
        `Sale Price` AS SaleAmount
    FROM ecommerce_db.ecommerce_dataset_c
    WHERE Status = 'Delivered'
),
yearly_sales AS (
    SELECT
        ProductCategory,
        OrderYear,
        SUM(SaleAmount) AS TotalSales
    FROM formatted_sales
    GROUP BY ProductCategory, OrderYear
),
sales_with_lag AS (
    SELECT
        ProductCategory,
        OrderYear,
        TotalSales,
        LAG(TotalSales) OVER (PARTITION BY ProductCategory ORDER BY OrderYear) AS PrevYearSales
    FROM yearly_sales
),
growth_calculated AS (
    SELECT
        ProductCategory,
        OrderYear,
        TotalSales AS CurrentYearSales,
        PrevYearSales AS PreviousYearSales,
        ROUND(((TotalSales - PrevYearSales) / PrevYearSales) * 100, 2) AS GrowthPercentage
    FROM sales_with_lag
    WHERE PrevYearSales IS NOT NULL
)
SELECT
    ProductCategory, OrderYear, CurrentYearSales, PreviousYearSales, GrowthPercentage
FROM growth_calculated
ORDER BY GrowthPercentage DESC
LIMIT 3;
















