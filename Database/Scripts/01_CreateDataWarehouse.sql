/*
    Script: 01_CreateDataWarehouse.sql
    Purpose: Create the data warehouse database
    Author: ETL Project
    Date: 2025-11-12
*/

USE master;
GO

-- Drop database if exists (for development)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'WideWorldImportersDW')
BEGIN
    ALTER DATABASE WideWorldImportersDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE WideWorldImportersDW;
END
GO

-- Create Data Warehouse Database
CREATE DATABASE WideWorldImportersDW
ON PRIMARY
(
    NAME = N'WideWorldImportersDW_Data',
    FILENAME = N'C:\SQLData\WideWorldImportersDW.mdf',
    SIZE = 1GB,
    FILEGROWTH = 256MB
)
LOG ON
(
    NAME = N'WideWorldImportersDW_Log',
    FILENAME = N'C:\SQLData\WideWorldImportersDW_log.ldf',
    SIZE = 512MB,
    FILEGROWTH = 128MB
);
GO

ALTER DATABASE WideWorldImportersDW SET RECOVERY SIMPLE;
GO

USE WideWorldImportersDW;
GO

PRINT 'Data Warehouse Database Created Successfully';
GO
