# Testing and Validation Guide

## Pre-Deployment Testing

### 1. Source Database Validation

```sql
-- Verify WideWorldImporters database is restored
USE master;
GO

SELECT 
    name AS DatabaseName,
    state_desc AS Status,
    recovery_model_desc AS RecoveryModel,
    create_date AS CreatedDate
FROM sys.databases
WHERE name = 'WideWorldImporters';

-- Check key source tables
USE WideWorldImporters;
GO

SELECT 'Customers' AS TableName, COUNT(*) AS RowCount FROM Sales.Customers
UNION ALL SELECT 'StockItems', COUNT(*) FROM Warehouse.StockItems
UNION ALL SELECT 'Invoices', COUNT(*) FROM Sales.Invoices
UNION ALL SELECT 'InvoiceLines', COUNT(*) FROM Sales.InvoiceLines
UNION ALL SELECT 'Cities', COUNT(*) FROM Application.Cities
UNION ALL SELECT 'People', COUNT(*) FROM Application.People WHERE IsSalesperson = 1;
```

**Expected Results:**
- Database should be in ONLINE status
- All tables should have data (row count > 0)
- Minimum expected: 663 customers, 227 stock items, thousands of invoices

### 2. Data Warehouse Creation

```sql
-- Execute deployment script
-- From SSMS, run: Database/Scripts/04_DeployAll.sql

-- Verify database creation
USE master;
GO

SELECT 
    name AS DatabaseName,
    state_desc AS Status,
    create_date AS CreatedDate
FROM sys.databases
WHERE name = 'WideWorldImportersDW';
```

### 3. Schema Validation

```sql
USE WideWorldImportersDW;
GO

-- Verify all tables exist
SELECT 
    t.name AS TableName,
    s.name AS SchemaName
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
ORDER BY t.name;
```

**Expected Tables:**
- DimCustomer
- DimDate
- DimGeography
- DimProduct
- DimSalesPerson
- FactSales

### 4. Primary Key Validation

```sql
-- Verify all primary keys are created
SELECT 
    t.name AS TableName,
    kc.name AS PrimaryKeyName,
    c.name AS ColumnName
FROM sys.key_constraints kc
INNER JOIN sys.tables t ON kc.parent_object_id = t.object_id
INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id 
    AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id 
    AND ic.column_id = c.column_id
WHERE kc.type = 'PK'
ORDER BY t.name;
```

**Expected Primary Keys:**
- DimCustomer → CustomerKey
- DimDate → DateKey
- DimGeography → GeographyKey
- DimProduct → ProductKey
- DimSalesPerson → SalesPersonKey
- FactSales → SalesKey

### 5. Foreign Key Validation

```sql
-- Verify all foreign keys are created
SELECT 
    fk.name AS ForeignKeyName,
    OBJECT_NAME(fk.parent_object_id) AS TableName,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ColumnName,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ReferencedColumn
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
ORDER BY TableName, ForeignKeyName;
```

**Expected Foreign Keys (5 total):**
- FactSales.CustomerKey → DimCustomer.CustomerKey
- FactSales.ProductKey → DimProduct.ProductKey
- FactSales.DateKey → DimDate.DateKey
- FactSales.GeographyKey → DimGeography.GeographyKey
- FactSales.SalesPersonKey → DimSalesPerson.SalesPersonKey

### 6. Index Validation

```sql
-- Verify indexes exist
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS IndexColumns
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id 
    AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id 
    AND ic.column_id = c.column_id
WHERE t.name IN ('DimCustomer', 'DimProduct', 'DimGeography', 'DimSalesPerson', 'FactSales')
GROUP BY t.name, i.name, i.type_desc
ORDER BY t.name, i.name;
```

### 7. Stored Procedure Validation

```sql
-- Verify all stored procedures exist
SELECT 
    name AS StoredProcedureName,
    create_date AS CreatedDate,
    modify_date AS ModifiedDate
FROM sys.procedures
WHERE name LIKE 'usp_%'
ORDER BY name;
```

**Expected Stored Procedures (9 total):**
- usp_GetProfitabilityAnalysis
- usp_GetSalesAnalysis
- usp_LoadDimCustomer
- usp_LoadDimDate
- usp_LoadDimGeography
- usp_LoadDimProduct
- usp_LoadDimSalesPerson
- usp_LoadFactSales
- usp_MasterETLProcess

## ETL Testing

### Test 1: Load Date Dimension

```sql
-- Execute DimDate load
EXEC dbo.usp_LoadDimDate 
    @StartDate = '2013-01-01', 
    @EndDate = '2025-12-31';

-- Verify row count
SELECT COUNT(*) AS DateCount FROM dbo.DimDate;
-- Expected: ~4,748 rows (13 years)

-- Verify data quality
SELECT 
    MIN(Date) AS MinDate,
    MAX(Date) AS MaxDate,
    COUNT(DISTINCT Year) AS YearCount,
    COUNT(*) AS TotalRows
FROM dbo.DimDate;

-- Check sample data
SELECT TOP 10 * FROM dbo.DimDate ORDER BY Date;
```

**Success Criteria:**
- Row count between 4,700 and 4,750
- Date range: 2013-01-01 to 2025-12-31
- All DateKey values in YYYYMMDD format
- No NULL values in required columns

### Test 2: Load Geography Dimension

```sql
-- Execute DimGeography load
EXEC dbo.usp_LoadDimGeography;

-- Verify row count
SELECT COUNT(*) AS GeographyCount FROM dbo.DimGeography;
-- Expected: ~110,000+ cities

-- Check data distribution
SELECT 
    CountryName,
    COUNT(*) AS CityCount
FROM dbo.DimGeography
GROUP BY CountryName
ORDER BY CityCount DESC;

-- Verify unique cities
SELECT COUNT(DISTINCT CityID) AS UniqueCities FROM dbo.DimGeography;
```

**Success Criteria:**
- Row count matches source: `SELECT COUNT(*) FROM WideWorldImporters.Application.Cities`
- No duplicate CityIDs
- All required fields populated

### Test 3: Load Customer Dimension

```sql
-- Execute DimCustomer load
EXEC dbo.usp_LoadDimCustomer;

-- Verify row count
SELECT COUNT(*) AS CustomerCount FROM dbo.DimCustomer;
-- Expected: 663 customers

-- Check SCD Type 2 implementation
SELECT 
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentRecords,
    SUM(CASE WHEN IsCurrent = 0 THEN 1 ELSE 0 END) AS HistoricalRecords
FROM dbo.DimCustomer;

-- Verify business key uniqueness for current records
SELECT CustomerID, COUNT(*) AS DuplicateCount
FROM dbo.DimCustomer
WHERE IsCurrent = 1
GROUP BY CustomerID
HAVING COUNT(*) > 1;
-- Expected: 0 rows (no duplicates)
```

**Success Criteria:**
- Current record count = source customer count
- All current records have IsCurrent = 1 and EndDate = NULL
- No duplicate CustomerIDs where IsCurrent = 1

### Test 4: Load Product Dimension

```sql
-- Execute DimProduct load
EXEC dbo.usp_LoadDimProduct;

-- Verify row count
SELECT COUNT(*) AS ProductCount FROM dbo.DimProduct;
-- Expected: 227 stock items

-- Check data completeness
SELECT 
    COUNT(*) AS TotalRecords,
    COUNT(DISTINCT StockItemID) AS UniqueProducts,
    SUM(CASE WHEN IsCurrent = 1 THEN 1 ELSE 0 END) AS CurrentProducts
FROM dbo.DimProduct;

-- Verify pricing data
SELECT 
    MIN(UnitPrice) AS MinPrice,
    MAX(UnitPrice) AS MaxPrice,
    AVG(UnitPrice) AS AvgPrice
FROM dbo.DimProduct
WHERE IsCurrent = 1;
```

**Success Criteria:**
- Product count matches source
- All UnitPrice values are positive
- No NULL values in critical fields

### Test 5: Load SalesPerson Dimension

```sql
-- Execute DimSalesPerson load
EXEC dbo.usp_LoadDimSalesPerson;

-- Verify row count
SELECT COUNT(*) AS SalesPersonCount FROM dbo.DimSalesPerson;
-- Expected: ~2 salespeople

-- Check current salespeople
SELECT 
    FullName,
    PreferredName,
    IsEmployee,
    IsSalesperson
FROM dbo.DimSalesPerson
WHERE IsCurrent = 1;
```

**Success Criteria:**
- Count matches source salespeople
- All have IsSalesperson = 1

### Test 6: Initial Fact Load (Small Sample)

```sql
-- Load facts for a single day first (testing)
EXEC dbo.usp_LoadFactSales @LoadDate = '2016-05-31';

-- Verify row count
SELECT COUNT(*) AS FactCount FROM dbo.FactSales;

-- Verify no orphaned records (all FKs valid)
SELECT 
    'Customer' AS DimensionCheck,
    COUNT(*) AS OrphanedRecords
FROM dbo.FactSales fs
LEFT JOIN dbo.DimCustomer dc ON fs.CustomerKey = dc.CustomerKey
WHERE dc.CustomerKey IS NULL

UNION ALL

SELECT 
    'Product',
    COUNT(*)
FROM dbo.FactSales fs
LEFT JOIN dbo.DimProduct dp ON fs.ProductKey = dp.ProductKey
WHERE dp.ProductKey IS NULL

UNION ALL

SELECT 
    'Date',
    COUNT(*)
FROM dbo.FactSales fs
LEFT JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey
WHERE dd.DateKey IS NULL;
-- Expected: 0 orphaned records in all dimensions
```

**Success Criteria:**
- Rows inserted > 0
- No orphaned records (all FK lookups successful)
- No duplicate InvoiceID/InvoiceLineID combinations

### Test 7: Data Quality Validation

```sql
-- Check for negative quantities or prices
SELECT 
    'Negative Quantity' AS Issue,
    COUNT(*) AS IssueCount
FROM dbo.FactSales
WHERE Quantity < 0

UNION ALL

SELECT 
    'Negative UnitPrice',
    COUNT(*)
FROM dbo.FactSales
WHERE UnitPrice < 0

UNION ALL

SELECT 
    'Negative ExtendedPrice',
    COUNT(*)
FROM dbo.FactSales
WHERE ExtendedPrice < 0;
-- Expected: All counts should be 0
```

### Test 8: Full ETL Process

```sql
-- Execute full initial load (WARNING: This may take several minutes)
EXEC dbo.usp_MasterETLProcess @InitialLoad = 1;

-- Check final row counts
SELECT 'DimDate' AS TableName, COUNT(*) AS RowCount FROM dbo.DimDate
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimGeography', COUNT(*) FROM dbo.DimGeography
UNION ALL SELECT 'DimSalesPerson', COUNT(*) FROM dbo.DimSalesPerson
UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales;
```

**Expected Results:**
- DimDate: ~4,748 rows
- DimCustomer: ~663 rows (current versions)
- DimProduct: ~227 rows (current versions)
- DimGeography: ~110,000+ rows
- DimSalesPerson: ~2 rows
- FactSales: ~70,000+ rows (depends on source data)

## Analysis Testing

### Test 9: Sales Summary Analysis

```sql
-- Test summary analysis
EXEC dbo.usp_GetSalesAnalysis 
    @StartDate = '2016-01-01',
    @EndDate = '2016-12-31',
    @AnalysisType = 'SUMMARY';
```

**Success Criteria:**
- Returns 1 row with summary statistics
- TotalRevenue > 0
- TotalProfit > 0
- ProfitMarginPercent is reasonable (typically 20-40%)

### Test 10: Customer Analysis

```sql
-- Test customer analysis
EXEC dbo.usp_GetSalesAnalysis 
    @AnalysisType = 'CUSTOMER';
```

**Success Criteria:**
- Returns top 20 customers
- All revenue values > 0
- Customers ordered by revenue (descending)

### Test 11: Product Analysis

```sql
-- Test product analysis
EXEC dbo.usp_GetSalesAnalysis 
    @AnalysisType = 'PRODUCT';
```

**Success Criteria:**
- Returns top 20 products
- All have valid product names
- Ordered by revenue

### Test 12: Profitability Analysis

```sql
-- Test profitability analysis
EXEC dbo.usp_GetProfitabilityAnalysis
    @StartDate = '2016-01-01',
    @EndDate = '2016-12-31';
```

**Success Criteria:**
- Returns multiple result sets
- Profit margins are calculated correctly
- No division by zero errors

## Performance Testing

### Test 13: Query Performance

```sql
-- Test fact table query performance
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- Query 1: Monthly aggregation
SELECT 
    d.Year,
    d.MonthName,
    SUM(f.ExtendedPrice) AS Revenue
FROM dbo.FactSales f
INNER JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY d.Year, d.Month, d.MonthName
ORDER BY d.Year, d.Month;

-- Query 2: Customer aggregation
SELECT TOP 10
    c.CustomerName,
    SUM(f.ExtendedPrice) AS Revenue
FROM dbo.FactSales f
INNER JOIN dbo.DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerName
ORDER BY Revenue DESC;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
```

**Success Criteria:**
- Queries complete in < 5 seconds
- Indexes are being used (check execution plan)

## Regression Testing

### Test 14: Incremental Load Testing

```sql
-- Test incremental load for specific date
DECLARE @TestDate DATE = '2016-06-01';

-- Record count before
DECLARE @CountBefore INT;
SELECT @CountBefore = COUNT(*) FROM dbo.FactSales;

-- Execute incremental load
EXEC dbo.usp_LoadFactSales @LoadDate = @TestDate;

-- Record count after
DECLARE @CountAfter INT;
SELECT @CountAfter = COUNT(*) FROM dbo.FactSales;

-- Display results
SELECT 
    @CountBefore AS RowsBefore,
    @CountAfter AS RowsAfter,
    @CountAfter - @CountBefore AS RowsInserted;
```

### Test 15: SCD Type 2 Testing

```sql
-- Test SCD Type 2 for customer
-- Simulate a customer change in source
UPDATE WideWorldImporters.Sales.Customers
SET PhoneNumber = '(555) 999-9999'
WHERE CustomerID = 1;

-- Run dimension load
EXEC dbo.usp_LoadDimCustomer;

-- Verify two versions exist
SELECT 
    CustomerKey,
    CustomerID,
    PhoneNumber,
    EffectiveDate,
    EndDate,
    IsCurrent
FROM dbo.DimCustomer
WHERE CustomerID = 1
ORDER BY EffectiveDate;
-- Expected: 2 rows, one with old phone, one with new phone
```

## Test Results Documentation

### Create Test Results Table

```sql
CREATE TABLE dbo.ETL_TestResults (
    TestID INT IDENTITY(1,1) PRIMARY KEY,
    TestName VARCHAR(200),
    TestDate DATETIME2 DEFAULT GETDATE(),
    TestStatus VARCHAR(20),
    ExpectedResult VARCHAR(MAX),
    ActualResult VARCHAR(MAX),
    TestNotes VARCHAR(MAX)
);
```

### Log Test Results

```sql
-- Example: Log a test result
INSERT INTO dbo.ETL_TestResults (TestName, TestStatus, ExpectedResult, ActualResult, TestNotes)
VALUES (
    'DimDate Load',
    'PASS',
    '4748 rows',
    '4748 rows loaded successfully',
    'Date range 2013-01-01 to 2025-12-31'
);
```

## Troubleshooting Failed Tests

### Common Issues and Solutions

**Issue: Foreign Key Violation in FactSales**
```sql
-- Diagnosis: Find missing dimension keys
SELECT DISTINCT i.CustomerID
FROM WideWorldImporters.Sales.Invoices i
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DimCustomer dc 
    WHERE dc.CustomerID = i.CustomerID AND dc.IsCurrent = 1
);

-- Solution: Reload customer dimension
EXEC dbo.usp_LoadDimCustomer;
```

**Issue: Duplicate Key Error**
```sql
-- Diagnosis: Find duplicates
SELECT InvoiceID, InvoiceLineID, COUNT(*) AS DuplicateCount
FROM dbo.FactSales
GROUP BY InvoiceID, InvoiceLineID
HAVING COUNT(*) > 1;

-- Solution: Delete duplicates and reload
DELETE FROM dbo.FactSales WHERE SalesKey IN (
    SELECT MAX(SalesKey) 
    FROM dbo.FactSales
    GROUP BY InvoiceID, InvoiceLineID
    HAVING COUNT(*) > 1
);
```

**Issue: No Data Loaded**
```sql
-- Diagnosis: Check source data for date
SELECT COUNT(*) 
FROM WideWorldImporters.Sales.Invoices 
WHERE CAST(InvoiceDate AS DATE) = '2016-05-31';

-- If count is 0, choose a different date with data
```

## Sign-Off Checklist

- [ ] All schemas created successfully
- [ ] All primary keys validated
- [ ] All foreign keys validated
- [ ] All indexes created
- [ ] All stored procedures created
- [ ] DimDate loaded and verified
- [ ] DimGeography loaded and verified
- [ ] DimCustomer loaded and verified
- [ ] DimProduct loaded and verified
- [ ] DimSalesPerson loaded and verified
- [ ] FactSales loaded and verified
- [ ] No orphaned records in fact table
- [ ] Analysis procedures execute successfully
- [ ] Query performance acceptable
- [ ] SCD Type 2 working correctly
- [ ] Documentation reviewed
- [ ] Test results logged

## Next Steps After Testing

1. **Production Deployment**: Deploy to production environment
2. **Schedule ETL**: Set up SQL Server Agent job
3. **Monitoring**: Implement monitoring and alerting
4. **User Training**: Train end users on analysis procedures
5. **Documentation**: Provide user guides and runbooks
