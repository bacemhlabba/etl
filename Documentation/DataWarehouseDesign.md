# Data Warehouse Design - Sales Analytics

## Analytical Topic: **Sales Performance Analysis**

This data warehouse is designed to analyze sales performance across multiple dimensions including:
- Customer demographics and segments
- Product categories and stock items
- Geographic regions (cities and states)
- Time-based trends (daily, monthly, quarterly, yearly)
- Sales personnel performance

## Dimensional Model: Star Schema

### Fact Table
**FactSales** - Contains transactional sales data

### Dimension Tables
1. **DimCustomer** - Customer information
2. **DimProduct** - Product and stock item details
3. **DimDate** - Time dimension for date-based analysis
4. **DimGeography** - Geographic information (cities, states, countries)
5. **DimSalesPerson** - Sales personnel information

## Architecture Diagram

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

## Table Specifications

### DimCustomer
- **Purpose**: Store customer master data
- **Type**: Type 2 Slowly Changing Dimension (SCD)
- **Source**: WideWorldImporters.Sales.Customers
- **Key Attributes**: CustomerKey, CustomerID, CustomerName, CustomerCategory, DeliveryCity

### DimProduct
- **Purpose**: Store product and stock item information
- **Type**: Type 2 SCD
- **Source**: WideWorldImporters.Warehouse.StockItems
- **Key Attributes**: ProductKey, StockItemID, StockItemName, Brand, Size, UnitPrice

### DimDate
- **Purpose**: Time dimension for date-based analysis
- **Type**: Type 0 (static)
- **Source**: Generated
- **Key Attributes**: DateKey, Date, Year, Quarter, Month, DayOfWeek

### DimGeography
- **Purpose**: Geographic location hierarchy
- **Type**: Type 1 SCD
- **Source**: WideWorldImporters.Application.Cities, States, Countries
- **Key Attributes**: GeographyKey, CityID, CityName, StateProvince, Country

### DimSalesPerson
- **Purpose**: Sales personnel information
- **Type**: Type 2 SCD
- **Source**: WideWorldImporters.Application.People
- **Key Attributes**: SalesPersonKey, PersonID, FullName, PreferredName

### FactSales
- **Purpose**: Store sales transaction facts
- **Type**: Transactional Fact Table
- **Source**: WideWorldImporters.Sales.Invoices, InvoiceLines
- **Measures**: Quantity, UnitPrice, TaxAmount, LineProfit, ExtendedPrice
- **Foreign Keys**: CustomerKey, ProductKey, DateKey, GeographyKey, SalesPersonKey

## Business Questions Answered

1. **Sales Trends**: What are the sales trends over time (daily, monthly, yearly)?
2. **Top Products**: Which products generate the most revenue and profit?
3. **Customer Analysis**: Who are the top customers by revenue?
4. **Geographic Performance**: Which cities/states have the highest sales?
5. **Sales Personnel**: Which salespeople are performing best?
6. **Profitability**: What is the profit margin by product category?
7. **Seasonal Patterns**: Are there seasonal patterns in sales?

## ETL Process Flow

1. **Extract**: Pull data from source WideWorldImporters tables
2. **Transform**: 
   - Cleanse and standardize data
   - Handle slowly changing dimensions
   - Calculate derived measures
3. **Load**: 
   - Load dimensions first (maintaining referential integrity)
   - Load fact table with proper foreign keys

## Refresh Strategy

- **Dimensions**: Incremental load with SCD Type 2 tracking
- **Facts**: Daily incremental load based on invoice date
- **Date Dimension**: Pre-populated for 10 years
