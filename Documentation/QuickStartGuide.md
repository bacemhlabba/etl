# Quick Start Guide - WideWorldImporters ETL

## 5-Minute Setup

### Step 1: Restore Source Database (2 minutes)

```sql
-- Download WideWorldImporters-Standard.bak from:
-- https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0

-- Restore database
RESTORE DATABASE WideWorldImporters
FROM DISK = 'C:\Backup\WideWorldImporters-Standard.bak'
WITH MOVE 'WWI_Primary' TO 'C:\SQLData\WideWorldImporters.mdf',
     MOVE 'WWI_UserData' TO 'C:\SQLData\WideWorldImporters_UserData.ndf',
     MOVE 'WWI_Log' TO 'C:\SQLData\WideWorldImporters.ldf',
     MOVE 'WWI_InMemory_Data_1' TO 'C:\SQLData\WideWorldImporters_InMemory_Data_1',
     REPLACE, RECOVERY;
GO
```

### Step 2: Deploy Data Warehouse (1 minute)

In SQL Server Management Studio (SSMS):
1. Open: `Database/Scripts/04_DeployAll.sql`
2. Update file paths in script if needed
3. Execute the script (F5)

### Step 3: Load Data (2 minutes)

```sql
USE WideWorldImportersDW;
GO

-- Execute initial data load
EXEC dbo.usp_MasterETLProcess @InitialLoad = 1;
GO
```

### Step 4: Run Your First Analysis

```sql
-- Get overall sales summary
EXEC dbo.usp_GetSalesAnalysis @AnalysisType = 'SUMMARY';
GO

-- View top customers
EXEC dbo.usp_GetSalesAnalysis @AnalysisType = 'CUSTOMER';
GO

-- See sales trends
EXEC dbo.usp_GetSalesAnalysis @AnalysisType = 'TREND';
GO
```

## Daily Operations

### Daily Incremental Load

```sql
-- Load yesterday's data
DECLARE @Yesterday DATE = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE);
EXEC dbo.usp_MasterETLProcess @InitialLoad = 0, @LoadDate = @Yesterday;
```

### Load Specific Date Range

```sql
-- Load data for May 2016
DECLARE @LoadDate DATE = '2016-05-01';
WHILE @LoadDate <= '2016-05-31'
BEGIN
    EXEC dbo.usp_LoadFactSales @LoadDate = @LoadDate;
    SET @LoadDate = DATEADD(DAY, 1, @LoadDate);
END
```

## Common Queries

### Check Data Warehouse Status

```sql
-- Row counts for all tables
SELECT 'DimDate' AS TableName, COUNT(*) AS RowCount FROM dbo.DimDate
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimGeography', COUNT(*) FROM dbo.DimGeography
UNION ALL SELECT 'DimSalesPerson', COUNT(*) FROM dbo.DimSalesPerson
UNION ALL SELECT 'FactSales', COUNT(*) FROM dbo.FactSales;

-- Latest data available
SELECT 
    MIN(dd.Date) AS EarliestSale,
    MAX(dd.Date) AS LatestSale,
    COUNT(DISTINCT dd.Date) AS DaysWithData
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey;
```

### Top 10 Products by Revenue

```sql
SELECT TOP 10
    p.StockItemName,
    p.Brand,
    SUM(f.ExtendedPrice) AS TotalRevenue,
    SUM(f.LineProfit) AS TotalProfit,
    SUM(f.Quantity) AS UnitsSold
FROM dbo.FactSales f
INNER JOIN dbo.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.StockItemName, p.Brand
ORDER BY TotalRevenue DESC;
```

### Monthly Sales by Geography

```sql
SELECT 
    g.CountryName,
    g.StateProvinceName,
    d.Year,
    d.MonthName,
    SUM(f.ExtendedPrice) AS Revenue,
    SUM(f.LineProfit) AS Profit
FROM dbo.FactSales f
INNER JOIN dbo.DimGeography g ON f.GeographyKey = g.GeographyKey
INNER JOIN dbo.DimDate d ON f.DateKey = d.DateKey
GROUP BY g.CountryName, g.StateProvinceName, d.Year, d.Month, d.MonthName
ORDER BY d.Year, d.Month, Revenue DESC;
```

### Sales Person Performance

```sql
SELECT 
    sp.FullName AS SalesPerson,
    COUNT(DISTINCT f.InvoiceID) AS Orders,
    COUNT(DISTINCT f.CustomerKey) AS Customers,
    SUM(f.ExtendedPrice) AS TotalRevenue,
    SUM(f.LineProfit) AS TotalProfit,
    AVG(f.ExtendedPrice) AS AvgOrderValue
FROM dbo.FactSales f
INNER JOIN dbo.DimSalesPerson sp ON f.SalesPersonKey = sp.SalesPersonKey
WHERE sp.IsCurrent = 1
GROUP BY sp.FullName
ORDER BY TotalRevenue DESC;
```

## Visual Studio 2022 SSIS Quick Setup

### Install SSIS Extension

1. Open **Visual Studio Installer**
2. Modify **Visual Studio 2022**
3. Install **SQL Server Integration Services Projects** extension

Or download from:
https://marketplace.visualstudio.com/items?itemName=SSIS.MicrosoftDataToolsIntegrationServices

### Create Project

1. **File** → **New** → **Project**
2. Search: "Integration Services"
3. Select: **Integration Services Project**
4. Name: `WideWorldImportersETL`

### Add Connection Managers

**Source Connection:**
- Name: `Source_WideWorldImporters`
- Server: Your SQL Server
- Database: `WideWorldImporters`

**Destination Connection:**
- Name: `Destination_WideWorldImportersDW`
- Server: Your SQL Server
- Database: `WideWorldImportersDW`

### Create Master ETL Package

Drag these tasks onto the Control Flow:

1. **Execute SQL Task** → "Load Dimensions"
   ```sql
   EXEC usp_LoadDimGeography;
   EXEC usp_LoadDimCustomer;
   EXEC usp_LoadDimProduct;
   EXEC usp_LoadDimSalesPerson;
   ```

2. **Execute SQL Task** → "Load Facts"
   ```sql
   EXEC usp_LoadFactSales @LoadDate = ?;
   ```
   - Map parameter to package variable

3. Connect tasks with precedence constraints (Success)

### Deploy Package

1. **Right-click project** → **Deploy**
2. Select **Integration Services Catalog**
3. Choose server and create folder `WideWorldImportersETL`
4. Complete deployment

## Scheduling with SQL Server Agent

### Create Daily ETL Job

```sql
USE msdb;
GO

-- Create job
EXEC dbo.sp_add_job  
    @job_name = N'Daily_ETL_WideWorldImporters';

-- Add job step
EXEC sp_add_jobstep  
    @job_name = N'Daily_ETL_WideWorldImporters',  
    @step_name = N'Execute ETL',  
    @subsystem = N'TSQL',  
    @command = N'EXEC WideWorldImportersDW.dbo.usp_MasterETLProcess @InitialLoad = 0;',
    @database_name = N'WideWorldImportersDW';

-- Schedule for daily at 2 AM
EXEC sp_add_schedule  
    @schedule_name = N'DailyAt2AM',  
    @freq_type = 4,  -- Daily
    @freq_interval = 1,  
    @active_start_time = 020000;  -- 02:00:00 AM

-- Attach schedule to job
EXEC sp_attach_schedule  
    @job_name = N'Daily_ETL_WideWorldImporters',  
    @schedule_name = N'DailyAt2AM';

-- Add job to server
EXEC dbo.sp_add_jobserver  
    @job_name = N'Daily_ETL_WideWorldImporters';
GO
```

## Troubleshooting

### Problem: "Cannot find stored procedure"
**Solution:**
```sql
-- Verify stored procedures exist
SELECT name FROM sys.procedures WHERE name LIKE 'usp_%';
```

### Problem: "Foreign key violation in FactSales"
**Solution:**
```sql
-- Ensure dimensions are loaded first
EXEC usp_LoadDimGeography;
EXEC usp_LoadDimCustomer;
EXEC usp_LoadDimProduct;
EXEC usp_LoadDimSalesPerson;
-- Then load facts
EXEC usp_LoadFactSales;
```

### Problem: "Duplicate key on FactSales"
**Solution:**
```sql
-- Check if data already loaded
SELECT COUNT(*) FROM FactSales 
WHERE DateKey = (SELECT DateKey FROM DimDate WHERE Date = '2016-05-31');
-- If already loaded, skip or delete and reload
```

### Problem: "No data in FactSales"
**Solution:**
```sql
-- Check source data exists
SELECT COUNT(*) FROM WideWorldImporters.Sales.Invoices;
-- Check dimension data exists
SELECT COUNT(*) FROM DimCustomer WHERE IsCurrent = 1;
SELECT COUNT(*) FROM DimProduct WHERE IsCurrent = 1;
```

## Performance Tips

### Index Maintenance
```sql
-- Rebuild indexes monthly
ALTER INDEX ALL ON dbo.FactSales REBUILD;
ALTER INDEX ALL ON dbo.DimCustomer REBUILD;
ALTER INDEX ALL ON dbo.DimProduct REBUILD;

-- Update statistics
UPDATE STATISTICS dbo.FactSales;
UPDATE STATISTICS dbo.DimCustomer;
UPDATE STATISTICS dbo.DimProduct;
```

### Query Optimization
```sql
-- Always filter by DateKey for better performance
-- Good:
SELECT * FROM FactSales WHERE DateKey BETWEEN 20160101 AND 20160131;

-- Avoid:
SELECT * FROM FactSales fs 
INNER JOIN DimDate dd ON fs.DateKey = dd.DateKey
WHERE dd.Date BETWEEN '2016-01-01' AND '2016-01-31';
```

## Next Steps

1. **Review design documentation**: `Documentation/DataWarehouseDesign.md`
2. **Explore SSIS setup**: `Documentation/SSIS_Setup_Guide.md`
3. **Customize analysis queries**: Modify `usp_GetSalesAnalysis` for specific needs
4. **Add more dimensions**: Extend the model with additional dimensions
5. **Implement data quality checks**: Add validation procedures
6. **Set up monitoring**: Create alerting for ETL failures

## Additional Resources

- Full Documentation: See `README.md`
- Database Design: `Documentation/DataWarehouseDesign.md`
- SSIS Guide: `Documentation/SSIS_Setup_Guide.md`
- Restore Guide: `Documentation/DatabaseRestore.md`
