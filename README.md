# WideWorldImporters ETL Data Warehouse Project

## Project Overview

This project implements a complete **Extract, Transform, Load (ETL)** solution for the WideWorldImporters database, creating a dimensional data warehouse optimized for **Sales Performance Analysis**.

### Analytical Topic: Sales Analytics

The data warehouse enables comprehensive analysis of:
- Sales trends over time (daily, monthly, quarterly, yearly)
- Top performing products and customers
- Geographic sales distribution
- Sales personnel performance
- Profitability analysis by multiple dimensions
- Seasonal patterns and trends

## Architecture

### Star Schema Design

The data warehouse follows a **star schema** dimensional model:

```
                    ┌─────────────────┐
                    │   DimCustomer   │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐         ┌─────▼──────┐      ┌─────▼─────┐
   │DimDate  │         │  FactSales │      │DimProduct │
   └────▲────┘         └─────┬──────┘      └───────────┘
        │                    │
        └────────────────────┼────────────────────┐
                             │                    │
                    ┌────────▼────────┐   ┌───────▼────────┐
                    │  DimGeography   │   │DimSalesPerson  │
                    └─────────────────┘   └────────────────┘
```

### Components

**Fact Table:**
- `FactSales` - Transactional sales data with measures (Quantity, Revenue, Profit, etc.)

**Dimension Tables:**
- `DimCustomer` - Customer master data (Type 2 SCD)
- `DimProduct` - Product and stock item information (Type 2 SCD)
- `DimDate` - Time dimension for date-based analysis
- `DimGeography` - Geographic hierarchy (City, State, Country)
- `DimSalesPerson` - Sales personnel information (Type 2 SCD)

**All relationships are established with Primary Keys and Foreign Keys** to maintain referential integrity.

## Project Structure

```
etl/
├── Database/
│   ├── Scripts/
│   │   ├── 01_CreateDataWarehouse.sql       # Create DW database
│   │   ├── 02_CreateDimensionTables.sql     # Create dimension tables with PKs
│   │   ├── 03_CreateFactTable.sql           # Create fact table with FKs
│   │   └── 04_DeployAll.sql                 # Master deployment script
│   └── StoredProcedures/
│       ├── usp_LoadDimDate.sql              # Load Date dimension
│       ├── usp_LoadDimGeography.sql         # Load Geography dimension
│       ├── usp_LoadDimCustomer.sql          # Load Customer dimension (SCD Type 2)
│       ├── usp_LoadDimProduct.sql           # Load Product dimension (SCD Type 2)
│       ├── usp_LoadDimSalesPerson.sql       # Load SalesPerson dimension (SCD Type 2)
│       ├── usp_LoadFactSales.sql            # Load Sales fact table
│       ├── usp_MasterETLProcess.sql         # Master ETL orchestration
│       └── usp_GetSalesAnalysis.sql         # Statistical analysis procedures
├── Documentation/
│   ├── DatabaseRestore.md                   # Database restore instructions
│   ├── DataWarehouseDesign.md               # Detailed design documentation
│   └── SSIS_Setup_Guide.md                  # Visual Studio 2022 SSIS guide
└── README.md                                # This file
```

## Getting Started

### Prerequisites

- SQL Server 2016 or later
- SQL Server Management Studio (SSMS)
- Visual Studio 2022 (for SSIS packages)
- SQL Server Data Tools (SSDT) - Integration Services extension
- WideWorldImporters-Standard.bak database backup

### Installation Steps

#### 1. Restore Source Database

Follow the instructions in [Documentation/DatabaseRestore.md](Documentation/DatabaseRestore.md) to restore the WideWorldImporters production database.

**Quick Restore:**
```sql
RESTORE DATABASE WideWorldImporters
FROM DISK = 'C:\Backup\WideWorldImporters-Standard.bak'
WITH MOVE 'WWI_Primary' TO 'C:\SQLData\WideWorldImporters.mdf',
     MOVE 'WWI_UserData' TO 'C:\SQLData\WideWorldImporters_UserData.ndf',
     MOVE 'WWI_Log' TO 'C:\SQLData\WideWorldImporters.ldf',
     MOVE 'WWI_InMemory_Data_1' TO 'C:\SQLData\WideWorldImporters_InMemory_Data_1',
     REPLACE, RECOVERY;
```

#### 2. Deploy Data Warehouse

**Option A: Using Master Deployment Script (Recommended)**

In SQL Server Management Studio, open and execute:
```
Database/Scripts/04_DeployAll.sql
```

**Option B: Execute Scripts Individually**

Execute in order:
1. `01_CreateDataWarehouse.sql`
2. `02_CreateDimensionTables.sql`
3. `03_CreateFactTable.sql`
4. All stored procedures in `StoredProcedures/` folder

#### 3. Initial Data Load

Execute the master ETL process for initial full load:

```sql
USE WideWorldImportersDW;
GO

-- Execute initial load (loads all historical data)
EXEC dbo.usp_MasterETLProcess @InitialLoad = 1;
```

**Note:** Initial load may take several minutes depending on data volume.

#### 4. Verify Data Load

Check row counts:

```sql
-- Verify dimension tables
SELECT 'DimDate' AS TableName, COUNT(*) AS RowCount FROM dbo.DimDate
UNION ALL
SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL
SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL
SELECT 'DimGeography', COUNT(*) FROM dbo.DimGeography
UNION ALL
SELECT 'DimSalesPerson', COUNT(*) FROM dbo.DimSalesPerson
UNION ALL
SELECT 'FactSales', COUNT(*) FROM dbo.FactSales;
```

## ETL Process

### Full Load vs Incremental Load

**Initial/Full Load:**
```sql
EXEC dbo.usp_MasterETLProcess @InitialLoad = 1;
```

**Incremental Daily Load:**
```sql
-- Load data for a specific date
EXEC dbo.usp_MasterETLProcess @InitialLoad = 0, @LoadDate = '2016-05-31';
```

### ETL Workflow

1. **Load Dimensions** (in order):
   - DimDate (one-time population)
   - DimGeography (Type 1 SCD - overwrite)
   - DimCustomer (Type 2 SCD - history tracking)
   - DimProduct (Type 2 SCD - history tracking)
   - DimSalesPerson (Type 2 SCD - history tracking)

2. **Load Facts**:
   - FactSales (incremental by date)

### Slowly Changing Dimensions (SCD)

The ETL implements **Type 2 SCD** for tracking historical changes:
- When a dimension attribute changes, the old record is end-dated
- A new record is inserted with current values
- `IsCurrent` flag identifies the current version
- `EffectiveDate` and `EndDate` track validity periods

## Data Analysis

### Running Analysis Reports

The `usp_GetSalesAnalysis` stored procedure provides multiple analysis types:

#### 1. Sales Summary
```sql
EXEC dbo.usp_GetSalesAnalysis 
    @StartDate = '2015-01-01', 
    @EndDate = '2016-12-31',
    @AnalysisType = 'SUMMARY';
```

#### 2. Top Customers Analysis
```sql
EXEC dbo.usp_GetSalesAnalysis 
    @StartDate = '2016-01-01', 
    @EndDate = '2016-12-31',
    @AnalysisType = 'CUSTOMER';
```

#### 3. Product Performance
```sql
EXEC dbo.usp_GetSalesAnalysis 
    @AnalysisType = 'PRODUCT';
```

#### 4. Geographic Analysis
```sql
EXEC dbo.usp_GetSalesAnalysis 
    @AnalysisType = 'GEOGRAPHY';
```

#### 5. Sales Person Performance
```sql
EXEC dbo.usp_GetSalesAnalysis 
    @AnalysisType = 'SALESPERSON';
```

#### 6. Monthly Sales Trends
```sql
EXEC dbo.usp_GetSalesAnalysis 
    @AnalysisType = 'TREND';
```

### Sample Business Questions Answered

1. **What is our total revenue and profit margin?**
   - Use `@AnalysisType = 'SUMMARY'`

2. **Who are our top 20 customers by revenue?**
   - Use `@AnalysisType = 'CUSTOMER'`

3. **Which products generate the most profit?**
   - Use `@AnalysisType = 'PRODUCT'`

4. **Which geographic regions have the highest sales?**
   - Use `@AnalysisType = 'GEOGRAPHY'`

5. **How are our salespeople performing?**
   - Use `@AnalysisType = 'SALESPERSON'`

6. **What are the monthly sales trends?**
   - Use `@AnalysisType = 'TREND'`

## SSIS Integration

### Setting Up SSIS Packages in Visual Studio 2022

Detailed instructions are available in [Documentation/SSIS_Setup_Guide.md](Documentation/SSIS_Setup_Guide.md).

**Quick Start:**

1. Install **SQL Server Data Tools** extension for Visual Studio 2022
2. Create **Integration Services Project**
3. Configure connection managers for source and destination databases
4. Create packages for:
   - Master ETL orchestration
   - Dimension loading
   - Fact table loading
5. Deploy to **SSIS Catalog (SSISDB)**
6. Schedule with **SQL Server Agent**

### Recommended SSIS Package Structure

- **Master_ETL_Package.dtsx** - Orchestrates full ETL process
- **Load_Dimensions.dtsx** - Loads all dimension tables
- **Load_Facts.dtsx** - Loads fact table with lookups

## Database Relationships

All tables have properly defined **Primary Keys (PK)** and **Foreign Keys (FK)**:

### Primary Keys

- `DimDate.DateKey` (PK)
- `DimCustomer.CustomerKey` (PK)
- `DimProduct.ProductKey` (PK)
- `DimGeography.GeographyKey` (PK)
- `DimSalesPerson.SalesPersonKey` (PK)
- `FactSales.SalesKey` (PK)

### Foreign Key Relationships

- `FactSales.CustomerKey` → `DimCustomer.CustomerKey` (FK)
- `FactSales.ProductKey` → `DimProduct.ProductKey` (FK)
- `FactSales.DateKey` → `DimDate.DateKey` (FK)
- `FactSales.GeographyKey` → `DimGeography.GeographyKey` (FK)
- `FactSales.SalesPersonKey` → `DimSalesPerson.SalesPersonKey` (FK)

**Referential integrity is enforced** through these foreign key constraints, ensuring data quality.

## Performance Optimization

### Indexes

The solution includes optimized indexes:

1. **Clustered Indexes**: Primary keys on all tables
2. **Nonclustered Indexes**: 
   - Business keys on dimensions (for lookups)
   - Foreign keys on fact table
   - Covering indexes for common queries

### Best Practices Implemented

- Star schema for optimal query performance
- Surrogate keys for dimension tables
- Partitioning strategy ready (by date)
- Indexed views capability for aggregations
- Separate staging environment recommended for production

## Maintenance

### Regular ETL Schedule

Recommended schedule:
- **Daily**: Incremental fact load for previous day
- **Weekly**: Full dimension refresh
- **Monthly**: Data quality checks and index maintenance

### Monitoring

Monitor ETL execution:
```sql
-- Check last ETL load date
SELECT MAX(ETLLoadDate) AS LastLoadDate
FROM dbo.FactSales;

-- Check data freshness
SELECT 
    MAX(dd.Date) AS LatestSalesDate,
    COUNT(*) AS TotalSalesRecords
FROM dbo.FactSales fs
INNER JOIN dbo.DimDate dd ON fs.DateKey = dd.DateKey;
```

## Troubleshooting

### Common Issues

**Issue**: Foreign key violation during fact load
- **Cause**: Dimension not loaded or missing lookup
- **Solution**: Ensure dimensions are loaded before facts

**Issue**: Duplicate key error
- **Cause**: Attempting to reload same data
- **Solution**: Check unique constraints and incremental load logic

**Issue**: Performance degradation
- **Cause**: Index fragmentation or missing statistics
- **Solution**: Rebuild indexes and update statistics

## Documentation

- [Database Restore Guide](Documentation/DatabaseRestore.md)
- [Data Warehouse Design](Documentation/DataWarehouseDesign.md)
- [SSIS Setup Guide](Documentation/SSIS_Setup_Guide.md)

## Technologies Used

- **SQL Server 2016+**: Database platform
- **T-SQL**: ETL logic and stored procedures
- **SSIS**: ETL orchestration (optional but recommended)
- **Visual Studio 2022**: SSIS package development
- **SSMS**: Database management and query execution

## Support

For issues or questions:
1. Review documentation in `/Documentation` folder
2. Check stored procedure comments for usage details
3. Verify source database is properly restored
4. Ensure proper permissions on both databases

## License

This is an educational project based on Microsoft's WideWorldImporters sample database.

## Acknowledgments

- Based on Microsoft's WideWorldImporters sample database
- Implements industry-standard dimensional modeling techniques
- Follows Kimball methodology for data warehouse design