-- SQL Script to clear the Dim DeliveryMethod table before ETL load
-- Run this script before executing the SSIS package to avoid duplicate key errors

USE [WideWorldImporters_DWH]
GO

-- Option 1: Delete all records (preserves table structure and indexes)
DELETE FROM [dbo].[Dim DeliveryMethod];
GO

-- Option 2: Truncate table (faster, but cannot be used if there are foreign key references)
-- TRUNCATE TABLE [dbo].[Dim DeliveryMethod];
-- GO

-- Verify the table is empty
SELECT COUNT(*) AS RecordCount FROM [dbo].[Dim DeliveryMethod];
GO
