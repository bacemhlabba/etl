USE [WideWorldImporters_DWH]
GO

-- View 1: Sales by Customer
CREATE OR ALTER VIEW vw_SalesByCustomer AS
SELECT 
    c.CustomerName,
    SUM(f.TotalAmount) AS TotalSales
FROM [dbo].[FactSales] f
INNER JOIN [dbo].[Dim Customer] c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerName;
GO

-- View 2: Sales by Delivery Method
CREATE OR ALTER VIEW vw_SalesByDeliveryMethod AS
SELECT 
    dm.DeliveryMethodName,
    SUM(f.TotalAmount) AS TotalSales
FROM [dbo].[FactSales] f
INNER JOIN [dbo].[Dim DeliveryMethod] dm ON f.DeliveryMethodKey = dm.DeliveryMethodKey
GROUP BY dm.DeliveryMethodName;
GO

-- View 3: Top 10 Stock Items by Sales
CREATE OR ALTER VIEW vw_TopStockItems AS
SELECT TOP 10
    si.StockItemName,
    SUM(f.TotalAmount) AS TotalSales
FROM [dbo].[FactSales] f
INNER JOIN [dbo].[Dim StockItemID] si ON f.StockItemKey = si.StockItemKey
GROUP BY si.StockItemName
ORDER BY TotalSales DESC;
GO

-- View 4: Sales by Month (requires date dimension or we'll use CreatedDate)
CREATE OR ALTER VIEW vw_SalesByMonth AS
SELECT 
    FORMAT(f.CreatedDate, 'yyyy-MM') AS YearMonth,
    SUM(f.TotalAmount) AS TotalSales
FROM [dbo].[FactSales] f
WHERE f.CreatedDate IS NOT NULL
GROUP BY FORMAT(f.CreatedDate, 'yyyy-MM');
GO

-- View 5: Quantity Sold by Stock Item (Top 15)
CREATE OR ALTER VIEW vw_QuantityByStockItem AS
SELECT TOP 15
    si.StockItemName,
    SUM(f.Quantity) AS TotalQuantity
FROM [dbo].[FactSales] f
INNER JOIN [dbo].[Dim StockItemID] si ON f.StockItemKey = si.StockItemKey
GROUP BY si.StockItemName
ORDER BY TotalQuantity DESC;
GO

-- Dashboard Metrics Views (NEW)
-- View 6: Dashboard Summary Statistics
CREATE OR ALTER VIEW vw_DashboardMetrics AS
SELECT 
    (SELECT COUNT(DISTINCT c.CustomerKey) FROM [dbo].[Dim Customer] c) AS TotalCustomers,
    (SELECT COUNT(DISTINCT si.StockItemKey) FROM [dbo].[Dim StockItemID] si) AS TotalStockItems,
    (SELECT COUNT(DISTINCT dm.DeliveryMethodKey) FROM [dbo].[Dim DeliveryMethod] dm) AS TotalDeliveryMethods,
    (SELECT COUNT(*) FROM [dbo].[FactSales]) AS TotalSalesRecords,
    (SELECT ISNULL(SUM(TotalAmount), 0) FROM [dbo].[FactSales]) AS GrandTotalSales,
    (SELECT ISNULL(AVG(TotalAmount), 0) FROM [dbo].[FactSales]) AS AverageSaleAmount,
    (SELECT COUNT(*) FROM [dbo].[Dim OrderLines]) AS TotalOrderLines,
    (SELECT ISNULL(SUM(Quantity), 0) FROM [dbo].[FactSales]) AS TotalQuantitySold,
    (SELECT ISNULL(SUM(TaxAmount), 0) FROM [dbo].[FactSales]) AS TotalTaxCollected,
    (SELECT COUNT(DISTINCT DateKey) FROM [dbo].[FactSales]) AS TotalUniqueDates;
GO

-- View 7: Recent Activity Status
CREATE OR ALTER VIEW vw_SystemStatus AS
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM [dbo].[FactSales]) THEN 'Operational'
        ELSE 'No Data'
    END AS SystemStatus,
    (SELECT MAX(CreatedDate) FROM [dbo].[FactSales]) AS LastTransactionDate,
    (SELECT COUNT(*) FROM [dbo].[FactSales] WHERE CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE)) AS TodaySalesCount,
    (SELECT ISNULL(SUM(TotalAmount), 0) FROM [dbo].[FactSales] WHERE CAST(CreatedDate AS DATE) = CAST(GETDATE() AS DATE)) AS TodaySalesAmount;
GO

-- View 8: Additional Stats for Dashboard Cards
CREATE OR ALTER VIEW vw_AdditionalStats AS
SELECT 
    -- Top Customer
    (SELECT TOP 1 c.CustomerName 
     FROM [dbo].[FactSales] f
     INNER JOIN [dbo].[Dim Customer] c ON f.CustomerKey = c.CustomerKey
     GROUP BY c.CustomerName
     ORDER BY SUM(f.TotalAmount) DESC) AS TopCustomerName,
    (SELECT TOP 1 SUM(f.TotalAmount)
     FROM [dbo].[FactSales] f
     INNER JOIN [dbo].[Dim Customer] c ON f.CustomerKey = c.CustomerKey
     GROUP BY c.CustomerName
     ORDER BY SUM(f.TotalAmount) DESC) AS TopCustomerSales,
    -- Top Product
    (SELECT TOP 1 si.StockItemName
     FROM [dbo].[FactSales] f
     INNER JOIN [dbo].[Dim StockItemID] si ON f.StockItemKey = si.StockItemKey
     GROUP BY si.StockItemName
     ORDER BY SUM(f.TotalAmount) DESC) AS TopProductName,
    (SELECT TOP 1 SUM(f.TotalAmount)
     FROM [dbo].[FactSales] f
     INNER JOIN [dbo].[Dim StockItemID] si ON f.StockItemKey = si.StockItemKey
     GROUP BY si.StockItemName
     ORDER BY SUM(f.TotalAmount) DESC) AS TopProductSales,
    -- Most Used Delivery Method
    (SELECT TOP 1 dm.DeliveryMethodName
     FROM [dbo].[FactSales] f
     INNER JOIN [dbo].[Dim DeliveryMethod] dm ON f.DeliveryMethodKey = dm.DeliveryMethodKey
     GROUP BY dm.DeliveryMethodName
     ORDER BY COUNT(*) DESC) AS MostUsedDeliveryMethod,
    (SELECT TOP 1 COUNT(*)
     FROM [dbo].[FactSales] f
     INNER JOIN [dbo].[Dim DeliveryMethod] dm ON f.DeliveryMethodKey = dm.DeliveryMethodKey
     GROUP BY dm.DeliveryMethodName
     ORDER BY COUNT(*) DESC) AS DeliveryMethodUsageCount;
GO

