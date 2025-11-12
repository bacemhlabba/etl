/*
    Script: 02_CreateDimensionTables.sql
    Purpose: Create dimension tables for the data warehouse
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

-- =============================================
-- Dimension Table: DimDate
-- =============================================
CREATE TABLE dbo.DimDate
(
    DateKey INT NOT NULL,
    Date DATE NOT NULL,
    DayOfMonth INT NOT NULL,
    DaySuffix VARCHAR(4) NOT NULL,
    DayName VARCHAR(10) NOT NULL,
    DayOfWeek INT NOT NULL,
    DayOfWeekInMonth INT NOT NULL,
    DayOfYear INT NOT NULL,
    WeekOfMonth INT NOT NULL,
    WeekOfYear INT NOT NULL,
    Month INT NOT NULL,
    MonthName VARCHAR(10) NOT NULL,
    Quarter INT NOT NULL,
    QuarterName VARCHAR(6) NOT NULL,
    Year INT NOT NULL,
    IsWeekend BIT NOT NULL,
    IsHoliday BIT NOT NULL DEFAULT 0,
    HolidayName VARCHAR(50) NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateKey)
);
GO

-- =============================================
-- Dimension Table: DimCustomer
-- Type 2 Slowly Changing Dimension
-- =============================================
CREATE TABLE dbo.DimCustomer
(
    CustomerKey INT IDENTITY(1,1) NOT NULL,
    CustomerID INT NOT NULL,  -- Business Key from source
    CustomerName NVARCHAR(100) NOT NULL,
    BillToCustomerID INT NULL,
    CustomerCategory NVARCHAR(50) NULL,
    BuyingGroup NVARCHAR(50) NULL,
    PrimaryContact NVARCHAR(100) NULL,
    AlternateContact NVARCHAR(100) NULL,
    DeliveryMethod NVARCHAR(50) NULL,
    DeliveryCity NVARCHAR(50) NULL,
    DeliveryPostalCode NVARCHAR(10) NULL,
    PhoneNumber NVARCHAR(20) NULL,
    FaxNumber NVARCHAR(20) NULL,
    WebsiteURL NVARCHAR(256) NULL,
    DeliveryLocation NVARCHAR(MAX) NULL,
    -- SCD Type 2 columns
    EffectiveDate DATE NOT NULL,
    EndDate DATE NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_DimCustomer PRIMARY KEY CLUSTERED (CustomerKey)
);
GO

CREATE NONCLUSTERED INDEX IX_DimCustomer_CustomerID 
ON dbo.DimCustomer (CustomerID, IsCurrent);
GO

-- =============================================
-- Dimension Table: DimProduct
-- Type 2 Slowly Changing Dimension
-- =============================================
CREATE TABLE dbo.DimProduct
(
    ProductKey INT IDENTITY(1,1) NOT NULL,
    StockItemID INT NOT NULL,  -- Business Key from source
    StockItemName NVARCHAR(100) NOT NULL,
    SupplierID INT NULL,
    SupplierName NVARCHAR(100) NULL,
    ColorID INT NULL,
    ColorName NVARCHAR(20) NULL,
    Brand NVARCHAR(50) NULL,
    Size NVARCHAR(20) NULL,
    LeadTimeDays INT NULL,
    QuantityPerOuter INT NULL,
    IsChillerStock BIT NULL,
    Barcode NVARCHAR(50) NULL,
    TaxRate DECIMAL(18,3) NULL,
    UnitPrice DECIMAL(18,2) NULL,
    RecommendedRetailPrice DECIMAL(18,2) NULL,
    TypicalWeightPerUnit DECIMAL(18,3) NULL,
    -- SCD Type 2 columns
    EffectiveDate DATE NOT NULL,
    EndDate DATE NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_DimProduct PRIMARY KEY CLUSTERED (ProductKey)
);
GO

CREATE NONCLUSTERED INDEX IX_DimProduct_StockItemID 
ON dbo.DimProduct (StockItemID, IsCurrent);
GO

-- =============================================
-- Dimension Table: DimGeography
-- Type 1 Slowly Changing Dimension
-- =============================================
CREATE TABLE dbo.DimGeography
(
    GeographyKey INT IDENTITY(1,1) NOT NULL,
    CityID INT NOT NULL,  -- Business Key from source
    CityName NVARCHAR(50) NOT NULL,
    StateProvinceID INT NOT NULL,
    StateProvinceName NVARCHAR(50) NOT NULL,
    StateProvinceCode NVARCHAR(5) NULL,
    CountryID INT NOT NULL,
    CountryName NVARCHAR(60) NOT NULL,
    Continent NVARCHAR(30) NOT NULL,
    Region NVARCHAR(30) NOT NULL,
    Subregion NVARCHAR(30) NOT NULL,
    LatestRecordedPopulation BIGINT NULL,
    CONSTRAINT PK_DimGeography PRIMARY KEY CLUSTERED (GeographyKey)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_DimGeography_CityID 
ON dbo.DimGeography (CityID);
GO

-- =============================================
-- Dimension Table: DimSalesPerson
-- Type 2 Slowly Changing Dimension
-- =============================================
CREATE TABLE dbo.DimSalesPerson
(
    SalesPersonKey INT IDENTITY(1,1) NOT NULL,
    PersonID INT NOT NULL,  -- Business Key from source
    FullName NVARCHAR(50) NOT NULL,
    PreferredName NVARCHAR(50) NOT NULL,
    IsPermittedToLogon BIT NOT NULL,
    LogonName NVARCHAR(50) NULL,
    IsExternalLogonProvider BIT NOT NULL,
    IsSystemUser BIT NOT NULL,
    IsEmployee BIT NOT NULL,
    IsSalesperson BIT NOT NULL,
    -- SCD Type 2 columns
    EffectiveDate DATE NOT NULL,
    EndDate DATE NULL,
    IsCurrent BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_DimSalesPerson PRIMARY KEY CLUSTERED (SalesPersonKey)
);
GO

CREATE NONCLUSTERED INDEX IX_DimSalesPerson_PersonID 
ON dbo.DimSalesPerson (PersonID, IsCurrent);
GO

PRINT 'Dimension Tables Created Successfully';
GO
