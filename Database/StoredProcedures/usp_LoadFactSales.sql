/*
    Stored Procedure: usp_LoadFactSales
    Purpose: Load Sales fact table from source database (Incremental Load)
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_LoadFactSales', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadFactSales;
GO

CREATE PROCEDURE dbo.usp_LoadFactSales
    @LoadDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to yesterday if no date provided
    IF @LoadDate IS NULL
        SET @LoadDate = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE);
    
    DECLARE @RowsInserted INT = 0;
    
    -- Insert new sales transactions
    INSERT INTO dbo.FactSales (
        CustomerKey,
        ProductKey,
        DateKey,
        GeographyKey,
        SalesPersonKey,
        InvoiceID,
        InvoiceLineID,
        OrderID,
        Quantity,
        UnitPrice,
        TaxRate,
        TaxAmount,
        LineProfit,
        ExtendedPrice
    )
    SELECT 
        dc.CustomerKey,
        dp.ProductKey,
        dd.DateKey,
        dg.GeographyKey,
        dsp.SalesPersonKey,
        i.InvoiceID,
        il.InvoiceLineID,
        i.OrderID,
        il.Quantity,
        il.UnitPrice,
        il.TaxRate,
        il.TaxAmount,
        il.LineProfit,
        il.ExtendedPrice
    FROM WideWorldImporters.Sales.Invoices i
    INNER JOIN WideWorldImporters.Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
    -- Join to dimensions to get surrogate keys
    INNER JOIN dbo.DimCustomer dc ON i.CustomerID = dc.CustomerID 
        AND dc.IsCurrent = 1
    INNER JOIN dbo.DimProduct dp ON il.StockItemID = dp.StockItemID 
        AND dp.IsCurrent = 1
    INNER JOIN dbo.DimDate dd ON CAST(i.InvoiceDate AS DATE) = dd.Date
    LEFT JOIN WideWorldImporters.Sales.Customers c ON i.CustomerID = c.CustomerID
    LEFT JOIN WideWorldImporters.Application.Cities city ON c.DeliveryCityID = city.CityID
    LEFT JOIN dbo.DimGeography dg ON city.CityID = dg.CityID
    LEFT JOIN dbo.DimSalesPerson dsp ON i.SalespersonPersonID = dsp.PersonID 
        AND dsp.IsCurrent = 1
    WHERE CAST(i.InvoiceDate AS DATE) = @LoadDate
    AND NOT EXISTS (
        SELECT 1 
        FROM dbo.FactSales fs 
        WHERE fs.InvoiceID = i.InvoiceID 
        AND fs.InvoiceLineID = il.InvoiceLineID
    );
    
    SET @RowsInserted = @@ROWCOUNT;
    
    PRINT 'FactSales loaded for ' + CAST(@LoadDate AS VARCHAR(10)) + ': ' 
          + CAST(@RowsInserted AS VARCHAR(10)) + ' rows inserted';
END
GO

PRINT 'Stored Procedure usp_LoadFactSales created successfully';
GO
