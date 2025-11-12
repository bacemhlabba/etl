/*
    Stored Procedure: usp_LoadDimProduct
    Purpose: Load Product dimension from source database (Type 2 SCD)
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_LoadDimProduct', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadDimProduct;
GO

CREATE PROCEDURE dbo.usp_LoadDimProduct
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    
    -- Handle Type 2 SCD: Expire changed records
    UPDATE dbo.DimProduct
    SET 
        EndDate = DATEADD(DAY, -1, @CurrentDate),
        IsCurrent = 0
    WHERE ProductKey IN (
        SELECT dp.ProductKey
        FROM dbo.DimProduct dp
        INNER JOIN WideWorldImporters.Warehouse.StockItems si ON dp.StockItemID = si.StockItemID
        LEFT JOIN WideWorldImporters.Purchasing.Suppliers sup ON si.SupplierID = sup.SupplierID
        LEFT JOIN WideWorldImporters.Warehouse.Colors col ON si.ColorID = col.ColorID
        WHERE dp.IsCurrent = 1
        AND (
            dp.StockItemName <> si.StockItemName OR
            ISNULL(dp.SupplierName, '') <> ISNULL(sup.SupplierName, '') OR
            ISNULL(dp.ColorName, '') <> ISNULL(col.ColorName, '') OR
            ISNULL(dp.Brand, '') <> ISNULL(si.Brand, '') OR
            ISNULL(dp.Size, '') <> ISNULL(si.Size, '') OR
            dp.UnitPrice <> si.UnitPrice OR
            ISNULL(dp.RecommendedRetailPrice, 0) <> ISNULL(si.RecommendedRetailPrice, 0)
        )
    );
    
    SET @RowsUpdated = @@ROWCOUNT;
    
    -- Insert new versions of changed records and completely new records
    INSERT INTO dbo.DimProduct (
        StockItemID,
        StockItemName,
        SupplierID,
        SupplierName,
        ColorID,
        ColorName,
        Brand,
        Size,
        LeadTimeDays,
        QuantityPerOuter,
        IsChillerStock,
        Barcode,
        TaxRate,
        UnitPrice,
        RecommendedRetailPrice,
        TypicalWeightPerUnit,
        EffectiveDate,
        EndDate,
        IsCurrent
    )
    SELECT 
        si.StockItemID,
        si.StockItemName,
        si.SupplierID,
        sup.SupplierName,
        si.ColorID,
        col.ColorName,
        si.Brand,
        si.Size,
        si.LeadTimeDays,
        si.QuantityPerOuter,
        si.IsChillerStock,
        si.Barcode,
        si.TaxRate,
        si.UnitPrice,
        si.RecommendedRetailPrice,
        si.TypicalWeightPerUnit,
        @CurrentDate,
        NULL,
        1
    FROM WideWorldImporters.Warehouse.StockItems si
    LEFT JOIN WideWorldImporters.Purchasing.Suppliers sup ON si.SupplierID = sup.SupplierID
    LEFT JOIN WideWorldImporters.Warehouse.Colors col ON si.ColorID = col.ColorID
    WHERE NOT EXISTS (
        SELECT 1 
        FROM dbo.DimProduct dp 
        WHERE dp.StockItemID = si.StockItemID 
        AND dp.IsCurrent = 1
        AND dp.StockItemName = si.StockItemName
        AND ISNULL(dp.SupplierName, '') = ISNULL(sup.SupplierName, '')
        AND ISNULL(dp.ColorName, '') = ISNULL(col.ColorName, '')
        AND ISNULL(dp.Brand, '') = ISNULL(si.Brand, '')
        AND ISNULL(dp.Size, '') = ISNULL(si.Size, '')
        AND dp.UnitPrice = si.UnitPrice
        AND ISNULL(dp.RecommendedRetailPrice, 0) = ISNULL(si.RecommendedRetailPrice, 0)
    );
    
    SET @RowsInserted = @@ROWCOUNT;
    
    PRINT 'DimProduct loaded: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows inserted, ' 
          + CAST(@RowsUpdated AS VARCHAR(10)) + ' rows expired';
END
GO

PRINT 'Stored Procedure usp_LoadDimProduct created successfully';
GO
