# SSIS Package Templates and Structure

## Visual Studio Solution Structure

When you create the SSIS project in Visual Studio 2022, the following structure will be generated:

```
WideWorldImportersETL/
├── WideWorldImportersETL.sln              # Visual Studio Solution
├── WideWorldImportersETL/
│   ├── WideWorldImportersETL.dtproj       # SSIS Project file
│   ├── Project.params                      # Project parameters
│   ├── Connection Managers/
│   │   ├── Source_WideWorldImporters.conmgr
│   │   └── Destination_WideWorldImportersDW.conmgr
│   └── SSIS Packages/
│       ├── Master_ETL_Package.dtsx
│       ├── Load_Dimensions.dtsx
│       └── Load_Facts.dtsx
```

## Package 1: Master_ETL_Package.dtsx

### Purpose
Orchestrate the complete ETL process by executing stored procedures in the correct order.

### Package Variables
- `LoadDate` (DateTime): Date for which to load data
- `InitialLoad` (Boolean): Flag for full vs incremental load

### Control Flow Design

```
┌─────────────────────────────────────────────┐
│ [Script Task] Set LoadDate                  │
│ - Sets LoadDate variable to yesterday       │
└──────────────┬──────────────────────────────┘
               │ (Success)
               ▼
┌─────────────────────────────────────────────┐
│ [Sequence Container] Load Dimensions         │
│  ┌─────────────────────────────────────────┐│
│  │ [Execute SQL] Load DimDate              ││
│  │   SQL: EXEC usp_LoadDimDate             ││
│  └──────────┬──────────────────────────────┘│
│             │ (Success)                      │
│  ┌──────────▼──────────────────────────────┐│
│  │ [Execute SQL] Load DimGeography         ││
│  │   SQL: EXEC usp_LoadDimGeography        ││
│  └──────────┬──────────────────────────────┘│
│             │ (Success)                      │
│  ┌──────────▼──────────────────────────────┐│
│  │ [Execute SQL] Load DimCustomer          ││
│  │   SQL: EXEC usp_LoadDimCustomer         ││
│  └──────────┬──────────────────────────────┘│
│             │ (Success)                      │
│  ┌──────────▼──────────────────────────────┐│
│  │ [Execute SQL] Load DimProduct           ││
│  │   SQL: EXEC usp_LoadDimProduct          ││
│  └──────────┬──────────────────────────────┘│
│             │ (Success)                      │
│  ┌──────────▼──────────────────────────────┐│
│  │ [Execute SQL] Load DimSalesPerson       ││
│  │   SQL: EXEC usp_LoadDimSalesPerson      ││
│  └─────────────────────────────────────────┘│
└──────────────┬──────────────────────────────┘
               │ (Success)
               ▼
┌─────────────────────────────────────────────┐
│ [Execute SQL] Load FactSales                │
│   SQL: EXEC usp_LoadFactSales @LoadDate = ? │
│   Parameter Mapping: 0 -> User::LoadDate   │
└──────────────┬──────────────────────────────┘
               │ (Success)
               ▼
┌─────────────────────────────────────────────┐
│ [Send Mail Task] ETL Success Notification   │
│   Subject: ETL Completed Successfully       │
└─────────────────────────────────────────────┘
```

### Configuration Steps

1. **Create Package Variables:**
   - Right-click in Control Flow → Variables
   - Add `LoadDate` (DateTime) = `DATEADD("day", -1, GETDATE())`
   - Add `InitialLoad` (Boolean) = `False`

2. **Add Script Task - Set LoadDate:**
   ```csharp
   public void Main()
   {
       // Set LoadDate to yesterday
       DateTime loadDate = DateTime.Today.AddDays(-1);
       Dts.Variables["User::LoadDate"].Value = loadDate;
       
       Dts.TaskResult = (int)ScriptResults.Success;
   }
   ```

3. **Add Sequence Container:**
   - Drag "Sequence Container" to Control Flow
   - Name: "Load Dimensions"

4. **Add Execute SQL Tasks:**
   For each dimension, add Execute SQL Task:
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadDim[TableName];`
   - Connect tasks with precedence constraints (green arrows)

5. **Add Execute SQL Task for Facts:**
   - Connection: Destination_WideWorldImportersDW
   - SQL Statement: `EXEC dbo.usp_LoadFactSales @LoadDate = ?;`
   - Parameter Mapping:
     - Variable Name: User::LoadDate
     - Direction: Input
     - Data Type: DATE
     - Parameter Name: 0

## Package 2: Load_Dimensions.dtsx

### Purpose
Detailed data flow implementation for loading dimensions with full ETL transformations.

### Data Flow: Load DimCustomer

```
┌──────────────────────────────────────┐
│ [OLE DB Source] Source Customers     │
│   Connection: Source_WideWorldImporters
│   SQL: SELECT CustomerID, CustomerName,
│        CustomerCategoryName, ...      │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ [Lookup] Find Existing Customer      │
│   Connection: Destination_WideWorldImportersDW
│   SQL: SELECT CustomerKey, CustomerID,
│        CustomerName, ...              │
│        WHERE IsCurrent = 1            │
└──────┬──────────────┬────────────────┘
       │              │
       │(No Match)    │(Match)
       │              │
       ▼              ▼
┌──────────┐   ┌────────────────────┐
│  New     │   │ [Conditional Split]│
│ Customer │   │ Has Changes?       │
└─────┬────┘   └──┬─────────────┬───┘
      │           │             │
      │           │(Changed)    │(No Change)
      │           │             │
      │           ▼             ▼
      │    ┌──────────────┐  [Do Nothing]
      │    │ Expire Old   │
      │    │ Record (SQL) │
      │    └──────┬───────┘
      │           │
      └───────────┴──────────────┐
                                 │
                                 ▼
                  ┌──────────────────────────┐
                  │ [Derived Column]         │
                  │ - EffectiveDate = GETDATE()
                  │ - IsCurrent = 1          │
                  │ - EndDate = NULL         │
                  └──────────┬───────────────┘
                             │
                             ▼
                  ┌──────────────────────────┐
                  │ [OLE DB Destination]     │
                  │ Table: DimCustomer       │
                  └──────────────────────────┘
```

### Configuration for OLE DB Source

**SQL Query:**
```sql
SELECT 
    c.CustomerID,
    c.CustomerName,
    c.BillToCustomerID,
    cc.CustomerCategoryName,
    bg.BuyingGroupName,
    pp.FullName AS PrimaryContactPersonName,
    ap.FullName AS AlternateContactPersonName,
    dm.DeliveryMethodName,
    city.CityName AS DeliveryCityName,
    c.DeliveryPostalCode,
    c.PhoneNumber,
    c.FaxNumber,
    c.WebsiteURL,
    c.DeliveryLocation
FROM Sales.Customers c
LEFT JOIN Sales.CustomerCategories cc ON c.CustomerCategoryID = cc.CustomerCategoryID
LEFT JOIN Sales.BuyingGroups bg ON c.BuyingGroupID = bg.BuyingGroupID
LEFT JOIN Application.People pp ON c.PrimaryContactPersonID = pp.PersonID
LEFT JOIN Application.People ap ON c.AlternateContactPersonID = ap.PersonID
LEFT JOIN Application.DeliveryMethods dm ON c.DeliveryMethodID = dm.DeliveryMethodID
LEFT JOIN Application.Cities city ON c.DeliveryCityID = city.CityID;
```

### Configuration for Lookup Transformation

**Lookup Query:**
```sql
SELECT 
    CustomerKey,
    CustomerID,
    CustomerName,
    CustomerCategory,
    BuyingGroup,
    DeliveryCity,
    DeliveryPostalCode,
    PhoneNumber,
    FaxNumber
FROM dbo.DimCustomer
WHERE IsCurrent = 1;
```

**Lookup Columns:**
- Join on: `CustomerID`
- Return: All columns for comparison

### Conditional Split Expression

```
(CustomerName != LOOKUP_CustomerName) || 
(ISNULL(CustomerCategory) != ISNULL(LOOKUP_CustomerCategory)) ||
(ISNULL(BuyingGroup) != ISNULL(LOOKUP_BuyingGroup)) ||
(ISNULL(DeliveryCity) != ISNULL(LOOKUP_DeliveryCity)) ||
(ISNULL(DeliveryPostalCode) != ISNULL(LOOKUP_DeliveryPostalCode)) ||
(ISNULL(PhoneNumber) != ISNULL(LOOKUP_PhoneNumber)) ||
(ISNULL(FaxNumber) != ISNULL(LOOKUP_FaxNumber))
```

## Package 3: Load_Facts.dtsx

### Purpose
Load fact table with all dimension lookups and measures.

### Data Flow: Load FactSales

```
┌───────────────────────────────────────────┐
│ [OLE DB Source] Source Sales Data         │
│   Connection: Source_WideWorldImporters   │
│   SQL: Query with date parameter          │
└──────────────┬────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────┐
│ [Lookup] Get CustomerKey                  │
│   No Match: Redirect to error             │
└──────────────┬────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────┐
│ [Lookup] Get ProductKey                   │
│   No Match: Redirect to error             │
└──────────────┬────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────┐
│ [Lookup] Get DateKey                      │
│   No Match: Redirect to error             │
└──────────────┬────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────┐
│ [Lookup] Get GeographyKey                 │
│   No Match: Use default (-1)              │
└──────────────┬────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────┐
│ [Lookup] Get SalesPersonKey               │
│   No Match: Use default (-1)              │
└──────────────┬────────────────────────────┘
               │
               ▼
┌───────────────────────────────────────────┐
│ [OLE DB Destination] FactSales            │
│   Table: dbo.FactSales                    │
│   Keep identity: No                       │
│   Keep nulls: No                          │
└───────────────────────────────────────────┘
```

### Source Query with Parameter

```sql
DECLARE @LoadDate DATE = ?;

SELECT 
    i.InvoiceID,
    il.InvoiceLineID,
    i.OrderID,
    i.CustomerID,
    il.StockItemID,
    CAST(i.InvoiceDate AS DATE) AS InvoiceDate,
    c.DeliveryCityID,
    i.SalespersonPersonID,
    il.Quantity,
    il.UnitPrice,
    il.TaxRate,
    il.TaxAmount,
    il.LineProfit,
    il.ExtendedPrice
FROM Sales.Invoices i
INNER JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
LEFT JOIN Sales.Customers c ON i.CustomerID = c.CustomerID
WHERE CAST(i.InvoiceDate AS DATE) = @LoadDate;
```

**Parameter Mapping:**
- Variable: User::LoadDate
- Parameter: 0

## Project Parameters

Create these project-level parameters for environment configuration:

1. **SourceServer** (String)
   - Description: Source SQL Server instance
   - Sensitive: No
   - Required: Yes
   - Default: "localhost"

2. **DestinationServer** (String)
   - Description: Destination SQL Server instance
   - Sensitive: No
   - Required: Yes
   - Default: "localhost"

3. **SourceDatabase** (String)
   - Description: Source database name
   - Sensitive: No
   - Required: Yes
   - Default: "WideWorldImporters"

4. **DestinationDatabase** (String)
   - Description: Destination database name
   - Sensitive: No
   - Required: Yes
   - Default: "WideWorldImportersDW"

## Error Handling

### Add Event Handlers

For each package, add these event handlers:

1. **OnError:**
   - Send Mail Task with error details
   - Log to SQL Server table

2. **OnPreExecute:**
   - Log start time and parameters

3. **OnPostExecute:**
   - Log end time and row counts

### Example Event Handler Script

```csharp
public void Main()
{
    string packageName = Dts.Variables["System::PackageName"].Value.ToString();
    string errorDescription = Dts.Variables["System::ErrorDescription"].Value.ToString();
    
    // Log error to database
    using (SqlConnection conn = new SqlConnection(Dts.Connections["Destination_WideWorldImportersDW"].ConnectionString))
    {
        conn.Open();
        SqlCommand cmd = new SqlCommand(
            "INSERT INTO ETL.ErrorLog (PackageName, ErrorDescription, ErrorDate) VALUES (@Package, @Error, GETDATE())", 
            conn);
        cmd.Parameters.AddWithValue("@Package", packageName);
        cmd.Parameters.AddWithValue("@Error", errorDescription);
        cmd.ExecuteNonQuery();
    }
    
    Dts.TaskResult = (int)ScriptResults.Success;
}
```

## Deployment Checklist

- [ ] All connection managers configured
- [ ] Package parameters defined
- [ ] Error handling implemented
- [ ] Logging configured
- [ ] Package protection level set
- [ ] Build successful with no warnings
- [ ] Test execution on development server
- [ ] Deploy to SSIS Catalog
- [ ] Create environment in SSISDB
- [ ] Map parameters to environment variables
- [ ] Test execution from catalog
- [ ] Create SQL Server Agent job
- [ ] Test scheduled execution

## Best Practices Applied

1. **Use package parameters** for all configuration values
2. **Implement comprehensive logging** for troubleshooting
3. **Handle errors gracefully** with redirects and notifications
4. **Use transactions** where appropriate
5. **Optimize data flow** with appropriate buffer sizes
6. **Document all transformations** with annotations
7. **Use checkpoints** for package restartability
8. **Version control** all SSIS packages
9. **Test thoroughly** before production deployment
10. **Monitor performance** and optimize as needed
