/*
    Stored Procedure: usp_GetSalesAnalysis
    Purpose: Generate comprehensive sales analysis statistics
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_GetSalesAnalysis', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetSalesAnalysis;
GO

CREATE PROCEDURE dbo.usp_GetSalesAnalysis
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @AnalysisType VARCHAR(50) = 'SUMMARY'  -- SUMMARY, CUSTOMER, PRODUCT, GEOGRAPHY, SALESPERSON, TREND
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to last 12 months if no dates provided
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -12, GETDATE());
    IF @EndDate IS NULL
        SET @EndDate = GETDATE();
    
    IF @AnalysisType = 'SUMMARY'
    BEGIN
        -- Overall sales summary
        SELECT 
            'Sales Summary' AS AnalysisType,
            COUNT(DISTINCT fs.InvoiceID) AS TotalInvoices,
            COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
            COUNT(DISTINCT fs.ProductKey) AS UniqueProducts,
            SUM(fs.Quantity) AS TotalQuantitySold,
            SUM(fs.ExtendedPrice) AS TotalRevenue,
            SUM(fs.LineProfit) AS TotalProfit,
            CASE 
                WHEN SUM(fs.ExtendedPrice) > 0 
                THEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 
                ELSE 0 
            END AS ProfitMarginPercent,
            AVG(fs.ExtendedPrice) AS AverageOrderValue
        FROM dbo.FactSales fs
        INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
        WHERE dd.Date BETWEEN @StartDate AND @EndDate;
    END
    
    ELSE IF @AnalysisType = 'CUSTOMER'
    BEGIN
        -- Top customers by revenue
        SELECT TOP 20
            dc.CustomerName,
            dc.CustomerCategory,
            dc.DeliveryCity,
            COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
            SUM(fs.Quantity) AS TotalQuantity,
            SUM(fs.ExtendedPrice) AS TotalRevenue,
            SUM(fs.LineProfit) AS TotalProfit,
            CASE 
                WHEN SUM(fs.ExtendedPrice) > 0 
                THEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 
                ELSE 0 
            END AS ProfitMarginPercent
        FROM dbo.FactSales fs
        INNER JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
        INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
        WHERE dd.Date BETWEEN @StartDate AND @EndDate
        GROUP BY dc.CustomerName, dc.CustomerCategory, dc.DeliveryCity
        ORDER BY TotalRevenue DESC;
    END
    
    ELSE IF @AnalysisType = 'PRODUCT'
    BEGIN
        -- Top products by revenue
        SELECT TOP 20
            dp.StockItemName,
            dp.Brand,
            dp.SupplierName,
            SUM(fs.Quantity) AS TotalQuantitySold,
            SUM(fs.ExtendedPrice) AS TotalRevenue,
            SUM(fs.LineProfit) AS TotalProfit,
            AVG(fs.UnitPrice) AS AverageUnitPrice,
            CASE 
                WHEN SUM(fs.ExtendedPrice) > 0 
                THEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 
                ELSE 0 
            END AS ProfitMarginPercent
        FROM dbo.FactSales fs
        INNER JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
        INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
        WHERE dd.Date BETWEEN @StartDate AND @EndDate
        GROUP BY dp.StockItemName, dp.Brand, dp.SupplierName
        ORDER BY TotalRevenue DESC;
    END
    
    ELSE IF @AnalysisType = 'GEOGRAPHY'
    BEGIN
        -- Sales by geography
        SELECT 
            dg.CountryName,
            dg.StateProvinceName,
            dg.CityName,
            COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
            COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
            SUM(fs.ExtendedPrice) AS TotalRevenue,
            SUM(fs.LineProfit) AS TotalProfit
        FROM dbo.FactSales fs
        INNER JOIN dbo.DimGeography dg ON fs.GeographyKey = dg.GeographyKey
        INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
        WHERE dd.Date BETWEEN @StartDate AND @EndDate
        GROUP BY dg.CountryName, dg.StateProvinceName, dg.CityName
        ORDER BY TotalRevenue DESC;
    END
    
    ELSE IF @AnalysisType = 'SALESPERSON'
    BEGIN
        -- Sales performance by salesperson
        SELECT 
            dsp.FullName AS SalesPersonName,
            dsp.PreferredName,
            COUNT(DISTINCT fs.CustomerKey) AS UniqueCustomers,
            COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
            SUM(fs.ExtendedPrice) AS TotalRevenue,
            SUM(fs.LineProfit) AS TotalProfit,
            AVG(fs.ExtendedPrice) AS AverageOrderValue
        FROM dbo.FactSales fs
        INNER JOIN dbo.DimSalesPerson dsp ON fs.SalesPersonKey = dsp.SalesPersonKey
        INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
        WHERE dd.Date BETWEEN @StartDate AND @EndDate
        GROUP BY dsp.FullName, dsp.PreferredName
        ORDER BY TotalRevenue DESC;
    END
    
    ELSE IF @AnalysisType = 'TREND'
    BEGIN
        -- Monthly sales trend
        SELECT 
            dd.Year,
            dd.Month,
            dd.MonthName,
            COUNT(DISTINCT fs.InvoiceID) AS OrderCount,
            SUM(fs.Quantity) AS TotalQuantity,
            SUM(fs.ExtendedPrice) AS TotalRevenue,
            SUM(fs.LineProfit) AS TotalProfit,
            CASE 
                WHEN SUM(fs.ExtendedPrice) > 0 
                THEN (SUM(fs.LineProfit) / SUM(fs.ExtendedPrice)) * 100 
                ELSE 0 
            END AS ProfitMarginPercent
        FROM dbo.FactSales fs
        INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
        WHERE dd.Date BETWEEN @StartDate AND @EndDate
        GROUP BY dd.Year, dd.Month, dd.MonthName
        ORDER BY dd.Year, dd.Month;
    END
END
GO

PRINT 'Stored Procedure usp_GetSalesAnalysis created successfully';
GO
