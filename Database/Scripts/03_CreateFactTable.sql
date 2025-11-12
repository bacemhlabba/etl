/*
    Script: 03_CreateFactTable.sql
    Purpose: Create fact table and establish relationships
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

-- =============================================
-- Fact Table: FactSales
-- Transactional fact table for sales analysis
-- =============================================
CREATE TABLE dbo.FactSales
(
    SalesKey BIGINT IDENTITY(1,1) NOT NULL,
    
    -- Dimension Foreign Keys
    CustomerKey INT NOT NULL,
    ProductKey INT NOT NULL,
    DateKey INT NOT NULL,
    GeographyKey INT NOT NULL,
    SalesPersonKey INT NOT NULL,
    
    -- Degenerate Dimensions (transaction identifiers)
    InvoiceID INT NOT NULL,
    InvoiceLineID INT NOT NULL,
    OrderID INT NULL,
    
    -- Measures
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    TaxRate DECIMAL(18,3) NOT NULL,
    TaxAmount DECIMAL(18,2) NOT NULL,
    LineProfit DECIMAL(18,2) NOT NULL,
    ExtendedPrice DECIMAL(18,2) NOT NULL,
    
    -- Audit columns
    ETLLoadDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT PK_FactSales PRIMARY KEY CLUSTERED (SalesKey)
);
GO

-- =============================================
-- Establish Foreign Key Relationships
-- =============================================

-- Foreign Key to DimCustomer
ALTER TABLE dbo.FactSales 
ADD CONSTRAINT FK_FactSales_DimCustomer 
FOREIGN KEY (CustomerKey) 
REFERENCES dbo.DimCustomer(CustomerKey);
GO

-- Foreign Key to DimProduct
ALTER TABLE dbo.FactSales 
ADD CONSTRAINT FK_FactSales_DimProduct 
FOREIGN KEY (ProductKey) 
REFERENCES dbo.DimProduct(ProductKey);
GO

-- Foreign Key to DimDate
ALTER TABLE dbo.FactSales 
ADD CONSTRAINT FK_FactSales_DimDate 
FOREIGN KEY (DateKey) 
REFERENCES dbo.DimDate(DateKey);
GO

-- Foreign Key to DimGeography
ALTER TABLE dbo.FactSales 
ADD CONSTRAINT FK_FactSales_DimGeography 
FOREIGN KEY (GeographyKey) 
REFERENCES dbo.DimGeography(GeographyKey);
GO

-- Foreign Key to DimSalesPerson
ALTER TABLE dbo.FactSales 
ADD CONSTRAINT FK_FactSales_DimSalesPerson 
FOREIGN KEY (SalesPersonKey) 
REFERENCES dbo.DimSalesPerson(SalesPersonKey);
GO

-- =============================================
-- Create Indexes for Query Performance
-- =============================================

-- Covering index for common queries by date
CREATE NONCLUSTERED INDEX IX_FactSales_DateKey 
ON dbo.FactSales (DateKey) 
INCLUDE (CustomerKey, ProductKey, ExtendedPrice, LineProfit);
GO

-- Index for customer analysis
CREATE NONCLUSTERED INDEX IX_FactSales_CustomerKey 
ON dbo.FactSales (CustomerKey) 
INCLUDE (DateKey, ExtendedPrice, LineProfit);
GO

-- Index for product analysis
CREATE NONCLUSTERED INDEX IX_FactSales_ProductKey 
ON dbo.FactSales (ProductKey) 
INCLUDE (DateKey, Quantity, ExtendedPrice, LineProfit);
GO

-- Index for geography analysis
CREATE NONCLUSTERED INDEX IX_FactSales_GeographyKey 
ON dbo.FactSales (GeographyKey) 
INCLUDE (DateKey, ExtendedPrice, LineProfit);
GO

-- Index for sales person analysis
CREATE NONCLUSTERED INDEX IX_FactSales_SalesPersonKey 
ON dbo.FactSales (SalesPersonKey) 
INCLUDE (DateKey, ExtendedPrice, LineProfit);
GO

-- Unique index to prevent duplicate invoices
CREATE UNIQUE NONCLUSTERED INDEX IX_FactSales_InvoiceLine 
ON dbo.FactSales (InvoiceID, InvoiceLineID);
GO

PRINT 'Fact Table and Relationships Created Successfully';
GO
