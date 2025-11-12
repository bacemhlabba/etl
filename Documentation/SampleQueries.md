# Sample Analysis Queries

This document provides ready-to-use SQL queries for analyzing the WideWorldImporters data warehouse.

## Table of Contents
1. [Sales Performance Queries](#sales-performance-queries)
2. [Customer Analytics](#customer-analytics)
3. [Product Analytics](#product-analytics)
4. [Geographic Analysis](#geographic-analysis)
5. [Time-Based Analysis](#time-based-analysis)
6. [Profitability Analysis](#profitability-analysis)
7. [Sales Team Performance](#sales-team-performance)

---

## Sales Performance Queries

### Overall Sales Summary
```sql
-- Get high-level sales metrics for the current year
SELECT 
    COUNT(DISTINCT fs.InvoiceID) AS TotalOrders,
    COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
    SUM(fs.Quantity) AS TotalUnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    FORMAT(AVG(fs.ExtendedPrice), 'C', 'en-US') AS AvgOrderValue,
    CAST((SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) AS DECIMAL(5,2)) AS ProfitMarginPct
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
WHERE dd.Year = 2016;
```

### Daily Sales Trend
```sql
-- View daily sales for the last 30 days
SELECT 
    dd.Date,
    dd.DayName,
    COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
    SUM(fs.Quantity) AS UnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS DailyRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS DailyProfit
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
WHERE dd.Date >= DATEADD(DAY, -30, GETDATE())
ORDER BY dd.Date DESC;
```

### Month-over-Month Growth
```sql
-- Calculate month-over-month sales growth
WITH MonthlySales AS (
    SELECT 
        dd.Year,
        dd.Month,
        dd.MonthName,
        SUM(fs.ExtendedPrice) AS Revenue,
        SUM(fs.LineProfit) AS Profit
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
    GROUP BY dd.Year, dd.Month, dd.MonthName
)
SELECT 
    Year,
    MonthName,
    FORMAT(Revenue, 'C', 'en-US') AS Revenue,
    FORMAT(Profit, 'C', 'en-US') AS Profit,
    FORMAT(Revenue - LAG(Revenue) OVER (ORDER BY Year, Month), 'C', 'en-US') AS RevenueChange,
    CAST(((Revenue - LAG(Revenue) OVER (ORDER BY Year, Month)) / 
          NULLIF(LAG(Revenue) OVER (ORDER BY Year, Month), 0) * 100) AS DECIMAL(5,2)) AS GrowthPct
FROM MonthlySales
ORDER BY Year, Month;
```

---

## Customer Analytics

### Top 20 Customers by Revenue
```sql
-- Identify top customers
SELECT TOP 20
    dc.CustomerName,
    dc.CustomerCategory,
    dc.DeliveryCity,
    COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
    SUM(fs.Quantity) AS TotalUnits,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    FORMAT(AVG(fs.ExtendedPrice), 'C', 'en-US') AS AvgOrderValue
FROM dbo.FactSales fs
INNER JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
WHERE dc.IsCurrent = 1
GROUP BY dc.CustomerName, dc.CustomerCategory, dc.DeliveryCity
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

### Customer Segmentation by Purchase Frequency
```sql
-- Segment customers by purchase frequency
WITH CustomerMetrics AS (
    SELECT 
        dc.CustomerKey,
        dc.CustomerName,
        COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
        SUM(fs.ExtendedPrice) AS TotalRevenue
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
    WHERE dc.IsCurrent = 1
    GROUP BY dc.CustomerKey, dc.CustomerName
)
SELECT 
    CASE 
        WHEN OrderCount >= 50 THEN 'VIP (50+ orders)'
        WHEN OrderCount >= 20 THEN 'Frequent (20-49 orders)'
        WHEN OrderCount >= 10 THEN 'Regular (10-19 orders)'
        ELSE 'Occasional (< 10 orders)'
    END AS CustomerSegment,
    COUNT(*) AS CustomerCount,
    FORMAT(SUM(TotalRevenue), 'C', 'en-US') AS SegmentRevenue,
    FORMAT(AVG(TotalRevenue), 'C', 'en-US') AS AvgRevenuePerCustomer
FROM CustomerMetrics
GROUP BY 
    CASE 
        WHEN OrderCount >= 50 THEN 'VIP (50+ orders)'
        WHEN OrderCount >= 20 THEN 'Frequent (20-49 orders)'
        WHEN OrderCount >= 10 THEN 'Regular (10-19 orders)'
        ELSE 'Occasional (< 10 orders)'
    END
ORDER BY SegmentRevenue DESC;
```

### Customer Lifetime Value
```sql
-- Calculate customer lifetime value
SELECT TOP 20
    dc.CustomerName,
    dc.CustomerCategory,
    MIN(dd.Date) AS FirstPurchaseDate,
    MAX(dd.Date) AS LastPurchaseDate,
    DATEDIFF(DAY, MIN(dd.Date), MAX(dd.Date)) AS DaysAsCustomer,
    COUNT(DISTINCT fs.InvoiceID) AS TotalOrders,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS LifetimeValue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS LifetimeProfit,
    FORMAT(SUM(fs.ExtendedPrice) / NULLIF(COUNT(DISTINCT fs.InvoiceID), 0), 'C', 'en-US') AS AvgOrderValue
FROM dbo.FactSales fs
INNER JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
WHERE dc.IsCurrent = 1
GROUP BY dc.CustomerName, dc.CustomerCategory
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

---

## Product Analytics

### Top 20 Products by Revenue
```sql
-- Identify best-selling products
SELECT TOP 20
    dp.StockItemName,
    dp.Brand,
    dp.Size,
    dp.SupplierName,
    SUM(fs.Quantity) AS UnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    CAST((SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) AS DECIMAL(5,2)) AS ProfitMarginPct,
    FORMAT(AVG(fs.UnitPrice), 'C', 'en-US') AS AvgSellingPrice
FROM dbo.FactSales fs
INNER JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
WHERE dp.IsCurrent = 1
GROUP BY dp.StockItemName, dp.Brand, dp.Size, dp.SupplierName
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

### Product Performance by Brand
```sql
-- Analyze sales by brand
SELECT 
    dp.Brand,
    COUNT(DISTINCT dp.StockItemID) AS ProductCount,
    SUM(fs.Quantity) AS TotalUnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    CAST((SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) AS DECIMAL(5,2)) AS ProfitMarginPct
FROM dbo.FactSales fs
INNER JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
WHERE dp.IsCurrent = 1 AND dp.Brand IS NOT NULL
GROUP BY dp.Brand
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

### Product ABC Analysis
```sql
-- ABC Classification: A=80% revenue, B=15% revenue, C=5% revenue
WITH ProductRevenue AS (
    SELECT 
        dp.StockItemName,
        SUM(fs.ExtendedPrice) AS Revenue,
        SUM(SUM(fs.ExtendedPrice)) OVER () AS TotalRevenue
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
    WHERE dp.IsCurrent = 1
    GROUP BY dp.StockItemName
),
RankedProducts AS (
    SELECT 
        StockItemName,
        Revenue,
        Revenue / TotalRevenue * 100 AS RevenuePct,
        SUM(Revenue / TotalRevenue * 100) OVER (ORDER BY Revenue DESC) AS CumulativePct
    FROM ProductRevenue
)
SELECT 
    StockItemName,
    FORMAT(Revenue, 'C', 'en-US') AS Revenue,
    CAST(RevenuePct AS DECIMAL(5,2)) AS RevenuePct,
    CAST(CumulativePct AS DECIMAL(5,2)) AS CumulativePct,
    CASE 
        WHEN CumulativePct <= 80 THEN 'A - High Value'
        WHEN CumulativePct <= 95 THEN 'B - Medium Value'
        ELSE 'C - Low Value'
    END AS ABCClass
FROM RankedProducts
ORDER BY Revenue DESC;
```

---

## Geographic Analysis

### Sales by Country
```sql
-- Revenue by country
SELECT 
    dg.CountryName,
    COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
    COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
    SUM(fs.Quantity) AS UnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    CAST((SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) AS DECIMAL(5,2)) AS ProfitMarginPct
FROM dbo.FactSales fs
INNER JOIN dbo.DimGeography dg ON fs.GeographyKey = dg.GeographyKey
GROUP BY dg.CountryName
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

### Top 20 Cities by Revenue
```sql
-- Identify high-performing cities
SELECT TOP 20
    dg.CityName,
    dg.StateProvinceName,
    dg.CountryName,
    COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    FORMAT(SUM(fs.ExtendedPrice) / NULLIF(COUNT(DISTINCT fs.CustomerKey), 0), 'C', 'en-US') AS RevenuePerCustomer
FROM dbo.FactSales fs
INNER JOIN dbo.DimGeography dg ON fs.GeographyKey = dg.GeographyKey
GROUP BY dg.CityName, dg.StateProvinceName, dg.CountryName
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

### Geographic Expansion Opportunities
```sql
-- Identify cities with customers but low sales
SELECT TOP 20
    dg.CityName,
    dg.StateProvinceName,
    dg.CountryName,
    COUNT(DISTINCT fs.CustomerKey) AS CustomerCount,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS CurrentRevenue,
    FORMAT(SUM(fs.ExtendedPrice) / NULLIF(COUNT(DISTINCT fs.CustomerKey), 0), 'C', 'en-US') AS RevenuePerCustomer,
    'Expansion Opportunity' AS Notes
FROM dbo.FactSales fs
INNER JOIN dbo.DimGeography dg ON fs.GeographyKey = dg.GeographyKey
GROUP BY dg.CityName, dg.StateProvinceName, dg.CountryName
HAVING COUNT(DISTINCT fs.CustomerKey) >= 5 
    AND SUM(fs.ExtendedPrice) / NULLIF(COUNT(DISTINCT fs.CustomerKey), 0) < 
        (SELECT AVG(fs.ExtendedPrice) FROM dbo.FactSales fs) * 10
ORDER BY COUNT(DISTINCT fs.CustomerKey) DESC;
```

---

## Time-Based Analysis

### Quarterly Performance
```sql
-- Quarterly sales comparison
SELECT 
    dd.Year,
    dd.Quarter,
    dd.QuarterName,
    COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
    SUM(fs.Quantity) AS UnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS Revenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS Profit,
    CAST((SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) AS DECIMAL(5,2)) AS ProfitMarginPct
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
GROUP BY dd.Year, dd.Quarter, dd.QuarterName
ORDER BY dd.Year, dd.Quarter;
```

### Day of Week Analysis
```sql
-- Sales pattern by day of week
SELECT 
    dd.DayName,
    dd.DayOfWeek,
    COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(AVG(fs.ExtendedPrice), 'C', 'en-US') AS AvgOrderValue,
    CASE WHEN dd.DayOfWeek IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS DayType
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
GROUP BY dd.DayName, dd.DayOfWeek
ORDER BY dd.DayOfWeek;
```

### Year-over-Year Comparison
```sql
-- Compare current year vs previous year
SELECT 
    dd.Month,
    dd.MonthName,
    FORMAT(SUM(CASE WHEN dd.Year = 2016 THEN fs.ExtendedPrice ELSE 0 END), 'C', 'en-US') AS Revenue2016,
    FORMAT(SUM(CASE WHEN dd.Year = 2015 THEN fs.ExtendedPrice ELSE 0 END), 'C', 'en-US') AS Revenue2015,
    FORMAT(SUM(CASE WHEN dd.Year = 2016 THEN fs.ExtendedPrice ELSE 0 END) - 
           SUM(CASE WHEN dd.Year = 2015 THEN fs.ExtendedPrice ELSE 0 END), 'C', 'en-US') AS Difference,
    CAST(((SUM(CASE WHEN dd.Year = 2016 THEN fs.ExtendedPrice ELSE 0 END) - 
           SUM(CASE WHEN dd.Year = 2015 THEN fs.ExtendedPrice ELSE 0 END)) /
           NULLIF(SUM(CASE WHEN dd.Year = 2015 THEN fs.ExtendedPrice ELSE 0 END), 0) * 100) AS DECIMAL(5,2)) AS GrowthPct
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
WHERE dd.Year IN (2015, 2016)
GROUP BY dd.Month, dd.MonthName
ORDER BY dd.Month;
```

---

## Profitability Analysis

### Profit Margin by Product Category
```sql
-- Analyze profitability by brand/category
SELECT 
    dp.Brand,
    COUNT(DISTINCT dp.ProductKey) AS ProductCount,
    SUM(fs.Quantity) AS UnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS Revenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS Profit,
    CAST((SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) AS DECIMAL(5,2)) AS MarginPct,
    CASE 
        WHEN (SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) >= 40 THEN 'High Margin'
        WHEN (SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100) >= 25 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS MarginCategory
FROM dbo.FactSales fs
INNER JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
WHERE dp.IsCurrent = 1 AND dp.Brand IS NOT NULL
GROUP BY dp.Brand
ORDER BY SUM(fs.LineProfit) DESC;
```

### Customer Profitability Tiers
```sql
-- Segment customers by profitability
WITH CustomerProfitability AS (
    SELECT 
        dc.CustomerKey,
        dc.CustomerName,
        dc.CustomerCategory,
        SUM(fs.ExtendedPrice) AS Revenue,
        SUM(fs.LineProfit) AS Profit,
        SUM(fs.LineProfit) / NULLIF(SUM(fs.ExtendedPrice), 0) * 100 AS ProfitMargin
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
    WHERE dc.IsCurrent = 1
    GROUP BY dc.CustomerKey, dc.CustomerName, dc.CustomerCategory
)
SELECT 
    CASE 
        WHEN ProfitMargin >= 35 THEN 'Highly Profitable'
        WHEN ProfitMargin >= 25 THEN 'Profitable'
        WHEN ProfitMargin >= 15 THEN 'Moderately Profitable'
        ELSE 'Low Profitability'
    END AS ProfitTier,
    COUNT(*) AS CustomerCount,
    FORMAT(SUM(Revenue), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(Profit), 'C', 'en-US') AS TotalProfit,
    CAST(AVG(ProfitMargin) AS DECIMAL(5,2)) AS AvgMargin
FROM CustomerProfitability
GROUP BY 
    CASE 
        WHEN ProfitMargin >= 35 THEN 'Highly Profitable'
        WHEN ProfitMargin >= 25 THEN 'Profitable'
        WHEN ProfitMargin >= 15 THEN 'Moderately Profitable'
        ELSE 'Low Profitability'
    END
ORDER BY AvgMargin DESC;
```

---

## Sales Team Performance

### Salesperson Performance Ranking
```sql
-- Rank salespeople by revenue
SELECT 
    dsp.FullName AS SalesPerson,
    dsp.PreferredName,
    COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
    COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
    SUM(fs.Quantity) AS UnitsSold,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS TotalRevenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS TotalProfit,
    FORMAT(AVG(fs.ExtendedPrice), 'C', 'en-US') AS AvgOrderValue,
    RANK() OVER (ORDER BY SUM(fs.ExtendedPrice) DESC) AS RevenueRank
FROM dbo.FactSales fs
INNER JOIN dbo.DimSalesPerson dsp ON fs.SalesPersonKey = dsp.SalesPersonKey
WHERE dsp.IsCurrent = 1
GROUP BY dsp.FullName, dsp.PreferredName
ORDER BY SUM(fs.ExtendedPrice) DESC;
```

### Salesperson Monthly Trends
```sql
-- Track salesperson performance over time
SELECT 
    dd.Year,
    dd.MonthName,
    dsp.PreferredName AS SalesPerson,
    COUNT(DISTINCT fs.InvoiceID) AS Orders,
    FORMAT(SUM(fs.ExtendedPrice), 'C', 'en-US') AS Revenue,
    FORMAT(SUM(fs.LineProfit), 'C', 'en-US') AS Profit
FROM dbo.FactSales fs
INNER JOIN dbo.DimSalesPerson dsp ON fs.SalesPersonKey = dsp.SalesPersonKey
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
WHERE dsp.IsCurrent = 1 AND dd.Year = 2016
GROUP BY dd.Year, dd.Month, dd.MonthName, dsp.PreferredName
ORDER BY dd.Month, SUM(fs.ExtendedPrice) DESC;
```

---

## Additional Useful Queries

### Data Freshness Check
```sql
-- Check when data was last loaded
SELECT 
    'FactSales' AS TableName,
    MAX(dd.Date) AS LatestDataDate,
    MAX(fs.ETLLoadDate) AS LastETLRun,
    DATEDIFF(DAY, MAX(dd.Date), GETDATE()) AS DaysOld
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey;
```

### Data Quality Check
```sql
-- Identify potential data quality issues
SELECT 
    'Negative Quantities' AS Issue,
    COUNT(*) AS RecordCount
FROM dbo.FactSales
WHERE Quantity < 0

UNION ALL

SELECT 
    'Zero or Negative Prices',
    COUNT(*)
FROM dbo.FactSales
WHERE UnitPrice <= 0

UNION ALL

SELECT 
    'Null Customer Keys',
    COUNT(*)
FROM dbo.FactSales
WHERE CustomerKey IS NULL;
```

---

## Tips for Using These Queries

1. **Customize Date Ranges**: Adjust `WHERE` clauses to focus on your desired time period
2. **Export Results**: Use SSMS export features or Power BI for visualization
3. **Optimize Performance**: Add appropriate indexes if queries are slow
4. **Schedule Reports**: Use SQL Server Agent to run queries on a schedule
5. **Combine Queries**: Join results from multiple queries for comprehensive analysis

## Next Steps

- Import these queries into your reporting tool (Power BI, Tableau, etc.)
- Create stored procedures for frequently-used queries
- Build dashboards based on these analytical insights
- Set up automated email reports using SSRS or Database Mail
