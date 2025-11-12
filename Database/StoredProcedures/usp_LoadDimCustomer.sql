/*
    Stored Procedure: usp_LoadDimCustomer
    Purpose: Load Customer dimension from source database (Type 2 SCD)
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_LoadDimCustomer', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadDimCustomer;
GO

CREATE PROCEDURE dbo.usp_LoadDimCustomer
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    
    -- Handle Type 2 SCD: Expire changed records
    UPDATE dbo.DimCustomer
    SET 
        EndDate = DATEADD(DAY, -1, @CurrentDate),
        IsCurrent = 0
    WHERE CustomerKey IN (
        SELECT dc.CustomerKey
        FROM dbo.DimCustomer dc
        INNER JOIN WideWorldImporters.Sales.Customers sc ON dc.CustomerID = sc.CustomerID
        WHERE dc.IsCurrent = 1
        AND (
            dc.CustomerName <> sc.CustomerName OR
            ISNULL(dc.CustomerCategory, '') <> ISNULL(sc.CustomerCategoryName, '') OR
            ISNULL(dc.BuyingGroup, '') <> ISNULL(sc.BuyingGroupName, '') OR
            ISNULL(dc.DeliveryCity, '') <> ISNULL(sc.DeliveryCityName, '') OR
            ISNULL(dc.DeliveryPostalCode, '') <> ISNULL(sc.DeliveryPostalCode, '') OR
            ISNULL(dc.PhoneNumber, '') <> ISNULL(sc.PhoneNumber, '') OR
            ISNULL(dc.FaxNumber, '') <> ISNULL(sc.FaxNumber, '')
        )
    );
    
    SET @RowsUpdated = @@ROWCOUNT;
    
    -- Insert new versions of changed records and completely new records
    INSERT INTO dbo.DimCustomer (
        CustomerID,
        CustomerName,
        BillToCustomerID,
        CustomerCategory,
        BuyingGroup,
        PrimaryContact,
        AlternateContact,
        DeliveryMethod,
        DeliveryCity,
        DeliveryPostalCode,
        PhoneNumber,
        FaxNumber,
        WebsiteURL,
        DeliveryLocation,
        EffectiveDate,
        EndDate,
        IsCurrent
    )
    SELECT 
        sc.CustomerID,
        sc.CustomerName,
        sc.BillToCustomerID,
        sc.CustomerCategoryName,
        sc.BuyingGroupName,
        sc.PrimaryContactPersonName,
        sc.AlternateContactPersonName,
        sc.DeliveryMethodName,
        sc.DeliveryCityName,
        sc.DeliveryPostalCode,
        sc.PhoneNumber,
        sc.FaxNumber,
        sc.WebsiteURL,
        sc.DeliveryLocation,
        @CurrentDate,
        NULL,
        1
    FROM WideWorldImporters.Sales.Customers sc
    WHERE NOT EXISTS (
        SELECT 1 
        FROM dbo.DimCustomer dc 
        WHERE dc.CustomerID = sc.CustomerID 
        AND dc.IsCurrent = 1
        AND dc.CustomerName = sc.CustomerName
        AND ISNULL(dc.CustomerCategory, '') = ISNULL(sc.CustomerCategoryName, '')
        AND ISNULL(dc.BuyingGroup, '') = ISNULL(sc.BuyingGroupName, '')
        AND ISNULL(dc.DeliveryCity, '') = ISNULL(sc.DeliveryCityName, '')
        AND ISNULL(dc.DeliveryPostalCode, '') = ISNULL(sc.DeliveryPostalCode, '')
        AND ISNULL(dc.PhoneNumber, '') = ISNULL(sc.PhoneNumber, '')
        AND ISNULL(dc.FaxNumber, '') = ISNULL(sc.FaxNumber, '')
    );
    
    SET @RowsInserted = @@ROWCOUNT;
    
    PRINT 'DimCustomer loaded: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows inserted, ' 
          + CAST(@RowsUpdated AS VARCHAR(10)) + ' rows expired';
END
GO

PRINT 'Stored Procedure usp_LoadDimCustomer created successfully';
GO
