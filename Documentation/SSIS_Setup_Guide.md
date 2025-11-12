# Visual Studio 2022 SSIS Setup Guide

## Overview
This guide explains how to create SSIS packages for the WideWorldImporters ETL project using Visual Studio 2022.

## Prerequisites

### Required Software
1. **Visual Studio 2022** (Community, Professional, or Enterprise)
2. **SQL Server Data Tools (SSDT)** - Integration Services Projects extension
3. **SQL Server Integration Services** installed on SQL Server instance

### Installing SSDT for Visual Studio 2022

1. Open **Visual Studio Installer**
2. Click **Modify** on your Visual Studio 2022 installation
3. Under **Workloads**, select:
   - Data storage and processing
4. Under **Individual Components**, search for and select:
   - SQL Server Integration Services Projects
5. Click **Modify** to install

Alternatively, download the extension directly:
- Visit: https://marketplace.visualstudio.com/items?itemName=SSIS.MicrosoftDataToolsIntegrationServices
- Download and install the SSIS Projects extension

## Creating the SSIS Solution

### Step 1: Create New Integration Services Project

1. Open **Visual Studio 2022**
2. Click **Create a new project**
3. Search for **Integration Services Project**
4. Select **Integration Services Project** template
5. Configure project:
   - **Project name**: WideWorldImportersETL
   - **Location**: Choose your workspace location
   - **Solution name**: WideWorldImportersETL
6. Click **Create**

### Step 2: Configure Connection Managers

Create two connection managers in the project:

#### Source Connection (WideWorldImporters)
1. Right-click in **Connection Managers** area
2. Select **New OLE DB Connection**
3. Click **New** to create new connection
4. Configure:
   - **Server name**: Your SQL Server instance
   - **Authentication**: Choose appropriate method
   - **Database**: WideWorldImporters
5. Name it: **Source_WideWorldImporters**

#### Destination Connection (WideWorldImportersDW)
1. Right-click in **Connection Managers** area
2. Select **New OLE DB Connection**
3. Click **New** to create new connection
4. Configure:
   - **Server name**: Your SQL Server instance
   - **Authentication**: Choose appropriate method
   - **Database**: WideWorldImportersDW
5. Name it: **Destination_WideWorldImportersDW**

## SSIS Package Design

### Package 1: Master_ETL_Package.dtsx

**Purpose**: Orchestrate the complete ETL process

**Control Flow Tasks**:

1. **Execute SQL Task**: "Load DimDate"
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadDimDate;`

2. **Execute SQL Task**: "Load DimGeography"
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadDimGeography;`

3. **Execute SQL Task**: "Load DimCustomer"
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadDimCustomer;`

4. **Execute SQL Task**: "Load DimProduct"
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadDimProduct;`

5. **Execute SQL Task**: "Load DimSalesPerson"
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadDimSalesPerson;`

6. **Execute SQL Task**: "Load FactSales"
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadFactSales @LoadDate = ?;`
   - Parameter Mapping: Add parameter for date

**Precedence Constraints**: Link tasks in sequence

### Package 2: Load_Dimensions.dtsx

**Purpose**: Load all dimension tables

**Data Flow Tasks**:

#### Data Flow 1: Load DimCustomer
- **OLE DB Source**: Query WideWorldImporters.Sales.Customers
- **Lookup**: Check existing customers in DimCustomer
- **Conditional Split**: Separate new vs changed customers
- **OLE DB Destination**: Insert into DimCustomer

#### Data Flow 2: Load DimProduct
- **OLE DB Source**: Query WideWorldImporters.Warehouse.StockItems
- **Lookup**: Check existing products in DimProduct
- **Conditional Split**: Separate new vs changed products
- **OLE DB Destination**: Insert into DimProduct

### Package 3: Load_Facts.dtsx

**Purpose**: Load fact table incrementally

**Data Flow Tasks**:

#### Data Flow 1: Load FactSales
- **OLE DB Source**: 
  ```sql
  SELECT 
      i.InvoiceID,
      il.InvoiceLineID,
      i.CustomerID,
      il.StockItemID,
      i.InvoiceDate,
      i.SalespersonPersonID,
      c.DeliveryCityID,
      il.Quantity,
      il.UnitPrice,
      il.TaxRate,
      il.TaxAmount,
      il.LineProfit,
      il.ExtendedPrice
  FROM Sales.Invoices i
  INNER JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
  LEFT JOIN Sales.Customers c ON i.CustomerID = c.CustomerID
  WHERE CAST(i.InvoiceDate AS DATE) = ?
  ```
- **Lookup Transformation**: Get CustomerKey from DimCustomer
- **Lookup Transformation**: Get ProductKey from DimProduct
- **Lookup Transformation**: Get DateKey from DimDate
- **Lookup Transformation**: Get GeographyKey from DimGeography
- **Lookup Transformation**: Get SalesPersonKey from DimSalesPerson
- **Derived Column**: Calculate any derived metrics
- **OLE DB Destination**: Insert into FactSales

## Package Configuration

### Variables

Create package-level variables:

1. **LoadDate** (DateTime): Date for incremental load
2. **SourceServer** (String): Source SQL Server instance
3. **DestinationServer** (String): Destination SQL Server instance

### Parameters

Create project parameters for environment configuration:

1. **SourceConnectionString** (String)
2. **DestinationConnectionString** (String)
3. **InitialLoad** (Boolean): Flag for full vs incremental load

## Deployment

### Step 1: Build the Project
1. Right-click on project in Solution Explorer
2. Select **Build**
3. Verify no build errors

### Step 2: Deploy to SQL Server
1. Right-click on project
2. Select **Deploy**
3. Follow Integration Services Deployment Wizard:
   - Choose **Integration Services Catalog** as destination
   - Select SQL Server instance
   - Choose or create catalog folder (e.g., "SSISDB/WideWorldImportersETL")
4. Click **Deploy**

### Step 3: Configure Environment
1. Open **SQL Server Management Studio**
2. Connect to Integration Services
3. Navigate to deployed project
4. Create environment with connection strings
5. Map parameters to environment variables

## Scheduling with SQL Server Agent

### Create SQL Server Agent Job

1. Open **SQL Server Management Studio**
2. Navigate to **SQL Server Agent** → **Jobs**
3. Right-click and select **New Job**
4. Configure job:
   - **Name**: Daily_ETL_WideWorldImportersDW
   - **Steps**: Add step to execute SSIS package
   - **Schedule**: Configure for daily execution

### Job Step Configuration
- **Type**: SQL Server Integration Services Package
- **Package source**: SSIS Catalog
- **Server**: Your SQL Server instance
- **Package**: \SSISDB\WideWorldImportersETL\Master_ETL_Package.dtsx

## Monitoring and Logging

### Enable SSIS Logging
1. Right-click in Control Flow designer
2. Select **Logging**
3. Enable logging providers:
   - SSIS log provider for SQL Server
4. Configure events to log:
   - OnError
   - OnWarning
   - OnPreExecute
   - OnPostExecute

### View Execution Reports
1. In SSMS, connect to Integration Services
2. Navigate to deployed package
3. Right-click → **Reports** → **All Executions**

## Troubleshooting

### Common Issues

**Issue**: Cannot find SSIS template in Visual Studio
- **Solution**: Reinstall SQL Server Data Tools extension

**Issue**: Package deployment fails
- **Solution**: Ensure SSIS Catalog (SSISDB) is created on target server

**Issue**: Connection failures during execution
- **Solution**: Verify connection strings and SQL Server authentication

## Best Practices

1. **Use Package Configurations**: Store connection strings in configurations
2. **Implement Error Handling**: Add error outputs and logging
3. **Use Checkpoints**: Enable package restart capability
4. **Optimize Data Flow**: Use appropriate buffer sizes
5. **Document Packages**: Add annotations to explain complex logic
6. **Version Control**: Keep SSIS project in source control (Git)

## Resources

- [SSIS Documentation](https://docs.microsoft.com/en-us/sql/integration-services/)
- [Visual Studio Marketplace - SSIS Extension](https://marketplace.visualstudio.com/items?itemName=SSIS.MicrosoftDataToolsIntegrationServices)
- [SQL Server Integration Services Tutorial](https://docs.microsoft.com/en-us/sql/integration-services/ssis-how-to-create-an-etl-package)
