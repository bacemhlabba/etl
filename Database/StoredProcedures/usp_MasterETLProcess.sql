/*
    Stored Procedure: usp_MasterETLProcess
    Purpose: Master ETL procedure to orchestrate the complete ETL process
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_MasterETLProcess', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MasterETLProcess;
GO

CREATE PROCEDURE dbo.usp_MasterETLProcess
    @InitialLoad BIT = 0,
    @LoadDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    DECLARE @StepName NVARCHAR(100);
    
    BEGIN TRY
        PRINT '=================================================';
        PRINT 'Starting ETL Process: ' + CAST(GETDATE() AS VARCHAR(30));
        PRINT '=================================================';
        
        -- Step 1: Load Date Dimension (only on initial load)
        IF @InitialLoad = 1
        BEGIN
            SET @StepName = 'Loading DimDate';
            PRINT '';
            PRINT @StepName + '...';
            EXEC dbo.usp_LoadDimDate;
            PRINT @StepName + ' - COMPLETED';
        END
        
        -- Step 2: Load Geography Dimension
        SET @StepName = 'Loading DimGeography';
        PRINT '';
        PRINT @StepName + '...';
        EXEC dbo.usp_LoadDimGeography;
        PRINT @StepName + ' - COMPLETED';
        
        -- Step 3: Load Customer Dimension
        SET @StepName = 'Loading DimCustomer';
        PRINT '';
        PRINT @StepName + '...';
        EXEC dbo.usp_LoadDimCustomer;
        PRINT @StepName + ' - COMPLETED';
        
        -- Step 4: Load Product Dimension
        SET @StepName = 'Loading DimProduct';
        PRINT '';
        PRINT @StepName + '...';
        EXEC dbo.usp_LoadDimProduct;
        PRINT @StepName + ' - COMPLETED';
        
        -- Step 5: Load SalesPerson Dimension
        SET @StepName = 'Loading DimSalesPerson';
        PRINT '';
        PRINT @StepName + '...';
        EXEC dbo.usp_LoadDimSalesPerson;
        PRINT @StepName + ' - COMPLETED';
        
        -- Step 6: Load Fact Table
        SET @StepName = 'Loading FactSales';
        PRINT '';
        PRINT @StepName + '...';
        
        IF @InitialLoad = 1
        BEGIN
            -- For initial load, load all historical data
            DECLARE @CurrentDate DATE;
            DECLARE @MinDate DATE;
            DECLARE @MaxDate DATE;
            
            SELECT @MinDate = MIN(InvoiceDate), @MaxDate = MAX(InvoiceDate)
            FROM WideWorldImporters.Sales.Invoices;
            
            SET @CurrentDate = @MinDate;
            
            WHILE @CurrentDate <= @MaxDate
            BEGIN
                EXEC dbo.usp_LoadFactSales @LoadDate = @CurrentDate;
                SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
            END
        END
        ELSE
        BEGIN
            -- Incremental load for specified date
            EXEC dbo.usp_LoadFactSales @LoadDate = @LoadDate;
        END
        
        PRINT @StepName + ' - COMPLETED';
        
        PRINT '';
        PRINT '=================================================';
        PRINT 'ETL Process Completed Successfully: ' + CAST(GETDATE() AS VARCHAR(30));
        PRINT '=================================================';
        
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorState = ERROR_STATE();
        
        PRINT '';
        PRINT '=================================================';
        PRINT 'ERROR in ' + @StepName;
        PRINT 'Error Message: ' + @ErrorMessage;
        PRINT '=================================================';
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT 'Stored Procedure usp_MasterETLProcess created successfully';
GO
