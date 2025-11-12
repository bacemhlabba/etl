# WideWorldImporters Database Restore Guide

## Overview
This document provides instructions for restoring the WideWorldImporters production database backup.

## Prerequisites
- SQL Server 2016 or later
- SQL Server Management Studio (SSMS)
- WideWorldImporters-Standard.bak file

## Download Database Backup
Download the WideWorldImporters-Standard.bak file from:
- Official Microsoft Sample: https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0

## Restore Steps

### Using SQL Server Management Studio (SSMS)

1. **Open SSMS** and connect to your SQL Server instance

2. **Right-click on Databases** → Select **Restore Database**

3. **Select Source**:
   - Choose **Device**
   - Click the **...** button
   - Add the WideWorldImporters-Standard.bak file

4. **Configure Restore Options**:
   - Database name: `WideWorldImporters`
   - Verify the backup set to restore
   - Check the **Files** page to ensure paths are correct

5. **Execute Restore**:
   - Click **OK** to start the restore process
   - Wait for completion message

### Using T-SQL

```sql
-- Restore the database using T-SQL
USE master;
GO

-- Check backup file contents
RESTORE FILELISTONLY 
FROM DISK = 'C:\Backup\WideWorldImporters-Standard.bak';
GO

-- Restore the database
RESTORE DATABASE WideWorldImporters
FROM DISK = 'C:\Backup\WideWorldImporters-Standard.bak'
WITH 
    MOVE 'WWI_Primary' TO 'C:\SQLData\WideWorldImporters.mdf',
    MOVE 'WWI_UserData' TO 'C:\SQLData\WideWorldImporters_UserData.ndf',
    MOVE 'WWI_Log' TO 'C:\SQLData\WideWorldImporters.ldf',
    MOVE 'WWI_InMemory_Data_1' TO 'C:\SQLData\WideWorldImporters_InMemory_Data_1',
    REPLACE,
    RECOVERY;
GO
```

## Verification

After restore, verify the database:

```sql
-- Check database status
SELECT name, state_desc, recovery_model_desc
FROM sys.databases
WHERE name = 'WideWorldImporters';

-- Verify table count
USE WideWorldImporters;
GO

SELECT 
    s.name AS SchemaName,
    COUNT(*) AS TableCount
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
GROUP BY s.name
ORDER BY s.name;
```

## Next Steps
After successful restore, proceed to:
1. Review the data warehouse design documentation
2. Execute the data warehouse creation scripts
3. Run ETL stored procedures
4. Configure SSIS packages
