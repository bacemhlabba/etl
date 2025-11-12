/*
    Script: 04_DeployAll.sql
    Purpose: Master deployment script to create entire data warehouse
    Author: ETL Project
    Date: 2025-11-12
    
    INSTRUCTIONS:
    1. Ensure WideWorldImporters database is restored first
    2. Execute this script in SQL Server Management Studio
    3. Script will create database, tables, and all stored procedures
*/

-- Step 1: Create Database
PRINT 'Step 1: Creating Data Warehouse Database...';
GO
:r 01_CreateDataWarehouse.sql
GO

-- Step 2: Create Dimension Tables
PRINT 'Step 2: Creating Dimension Tables...';
GO
:r 02_CreateDimensionTables.sql
GO

-- Step 3: Create Fact Table and Relationships
PRINT 'Step 3: Creating Fact Table and Relationships...';
GO
:r 03_CreateFactTable.sql
GO

-- Step 4: Create ETL Stored Procedures
PRINT 'Step 4: Creating ETL Stored Procedures...';
GO

-- Change to stored procedures directory
:r ..\StoredProcedures\usp_LoadDimDate.sql
GO
:r ..\StoredProcedures\usp_LoadDimGeography.sql
GO
:r ..\StoredProcedures\usp_LoadDimCustomer.sql
GO
:r ..\StoredProcedures\usp_LoadDimProduct.sql
GO
:r ..\StoredProcedures\usp_LoadDimSalesPerson.sql
GO
:r ..\StoredProcedures\usp_LoadFactSales.sql
GO
:r ..\StoredProcedures\usp_MasterETLProcess.sql
GO
:r ..\StoredProcedures\usp_GetSalesAnalysis.sql
GO

PRINT '';
PRINT '=================================================';
PRINT 'Data Warehouse Deployment Completed Successfully!';
PRINT '=================================================';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Execute initial data load:';
PRINT '   EXEC dbo.usp_MasterETLProcess @InitialLoad = 1;';
PRINT '';
PRINT '2. Run sales analysis:';
PRINT '   EXEC dbo.usp_GetSalesAnalysis @AnalysisType = ''SUMMARY'';';
PRINT '';
GO
