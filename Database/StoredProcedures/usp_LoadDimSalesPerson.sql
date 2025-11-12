/*
    Stored Procedure: usp_LoadDimSalesPerson
    Purpose: Load SalesPerson dimension from source database (Type 2 SCD)
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_LoadDimSalesPerson', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadDimSalesPerson;
GO

CREATE PROCEDURE dbo.usp_LoadDimSalesPerson
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    
    -- Handle Type 2 SCD: Expire changed records
    UPDATE dbo.DimSalesPerson
    SET 
        EndDate = DATEADD(DAY, -1, @CurrentDate),
        IsCurrent = 0
    WHERE SalesPersonKey IN (
        SELECT dsp.SalesPersonKey
        FROM dbo.DimSalesPerson dsp
        INNER JOIN WideWorldImporters.Application.People p ON dsp.PersonID = p.PersonID
        WHERE dsp.IsCurrent = 1
        AND p.IsSalesperson = 1
        AND (
            dsp.FullName <> p.FullName OR
            dsp.PreferredName <> p.PreferredName OR
            dsp.IsPermittedToLogon <> p.IsPermittedToLogon OR
            dsp.IsEmployee <> p.IsEmployee
        )
    );
    
    SET @RowsUpdated = @@ROWCOUNT;
    
    -- Insert new versions of changed records and completely new records
    INSERT INTO dbo.DimSalesPerson (
        PersonID,
        FullName,
        PreferredName,
        IsPermittedToLogon,
        LogonName,
        IsExternalLogonProvider,
        IsSystemUser,
        IsEmployee,
        IsSalesperson,
        EffectiveDate,
        EndDate,
        IsCurrent
    )
    SELECT 
        p.PersonID,
        p.FullName,
        p.PreferredName,
        p.IsPermittedToLogon,
        p.LogonName,
        p.IsExternalLogonProvider,
        p.IsSystemUser,
        p.IsEmployee,
        p.IsSalesperson,
        @CurrentDate,
        NULL,
        1
    FROM WideWorldImporters.Application.People p
    WHERE p.IsSalesperson = 1
    AND NOT EXISTS (
        SELECT 1 
        FROM dbo.DimSalesPerson dsp 
        WHERE dsp.PersonID = p.PersonID 
        AND dsp.IsCurrent = 1
        AND dsp.FullName = p.FullName
        AND dsp.PreferredName = p.PreferredName
        AND dsp.IsPermittedToLogon = p.IsPermittedToLogon
        AND dsp.IsEmployee = p.IsEmployee
    );
    
    SET @RowsInserted = @@ROWCOUNT;
    
    PRINT 'DimSalesPerson loaded: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows inserted, ' 
          + CAST(@RowsUpdated AS VARCHAR(10)) + ' rows expired';
END
GO

PRINT 'Stored Procedure usp_LoadDimSalesPerson created successfully';
GO
