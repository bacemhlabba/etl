/*
    Stored Procedure: usp_GetProfitabilityAnalysis
    Purpose: Generate detailed profitability insights
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_GetProfitabilityAnalysis', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetProfitabilityAnalysis;
GO

CREATE PROCEDURE dbo.usp_GetProfitabilityAnalysis
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to last 12 months if no dates provided
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -12, GETDATE());
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    -- Profitability by Product Category
    SELECT 
        'Product Profitability' AS AnalysisSection,
        dp.Brand,
        dp.SupplierName,
        COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
        SUM(fs.Quantity) AS TotalQuantitySold,
        SUM(fs.ExtendedPrice) AS TotalRevenue,
        SUM(fs.LineProfit) AS TotalProfit,
        AVG(fs.LineProfit) AS AvgProfitPerLine,
        CASE 
            WHEN SUM(fs.ExtendedPrice) > 0 
            THEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 
            ELSE 0 
        END AS ProfitMarginPercent,
        CASE
            WHEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 >= 40 THEN 'High Margin'
            WHEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 >= 20 THEN 'Medium Margin'
            ELSE 'Low Margin'
        END AS MarginCategory
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
    INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
    WHERE dd.Date BETWEEN @StartDate AND @EndDate
    AND dp.IsCurrent = 1
    GROUP BY dp.Brand, dp.SupplierName
    HAVING SUM(fs.ExtendedPrice) > 0
    ORDER BY ProfitMarginPercent DESC;
    
    -- Customer Profitability Segments
    SELECT 
        'Customer Segments' AS AnalysisSection,
        dc.CustomerCategory,
        COUNT(DISTINCT dc.CustomerKey) AS CustomerCount,
        COUNT(DISTINCT fs.InvoiceID) AS TotalOrders,
        SUM(fs.ExtendedPrice) AS TotalRevenue,
        SUM(fs.LineProfit) AS TotalProfit,
        AVG(fs.ExtendedPrice) AS AvgOrderValue,
        SUM(fs.ExtendedPrice) / NULLIF(COUNT(DISTINCT dc.CustomerKey), 0) AS RevenuePerCustomer,
        SUM(fs.LineProfit) / NULLIF(COUNT(DISTINCT dc.CustomerKey), 0) AS ProfitPerCustomer
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
    INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
    WHERE dd.Date BETWEEN @StartDate AND @EndDate
    AND dc.IsCurrent = 1
    GROUP BY dc.CustomerCategory
    ORDER BY TotalProfit DESC;
    
    -- Geographic Profitability
    SELECT TOP 20
        'Geographic Profitability' AS AnalysisSection,
        dg.CountryName,
        dg.StateProvinceName,
        dg.CityName,
        SUM(fs.ExtendedPrice) AS TotalRevenue,
        SUM(fs.LineProfit) AS TotalProfit,
        CASE 
            WHEN SUM(fs.ExtendedPrice) > 0 
            THEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 
            ELSE 0 
        END AS ProfitMarginPercent,
        COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers
    FROM dbo.FactSales fs
    INNER JOIN dbo.DimGeography dg ON fs.GeographyKey = dg.GeographyKey
    INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
    WHERE dd.Date BETWEEN @StartDate AND @EndDate
    GROUP BY dg.CountryName, dg.StateProvinceName, dg.CityName
    ORDER BY TotalProfit DESC;
END
GO

PRINT 'Stored Procedure usp_GetProfitabilityAnalysis created successfully';
GO
