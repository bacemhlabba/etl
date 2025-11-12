/*
    Script: CreateSQLAgentJob.sql
    Purpose: Create SQL Server Agent job for daily ETL execution
    Author: ETL Project
    Date: 2025-11-12
*/

USE msdb;
GO

-- Drop job if exists
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'Daily_ETL_WideWorldImportersDW')
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = N'Daily_ETL_WideWorldImportersDW', @delete_unused_schedule = 1;
END
GO

-- Create new job
EXEC dbo.sp_add_job  
    @job_name = N'Daily_ETL_WideWorldImportersDW',
    @enabled = 1,
    @description = N'Daily incremental ETL load for WideWorldImporters Data Warehouse',
    @category_name = N'Data Warehouse',
    @owner_login_name = N'sa';
GO

-- Add Step 1: Execute ETL Process
EXEC sp_add_jobstep  
    @job_name = N'Daily_ETL_WideWorldImportersDW',  
    @step_name = N'Execute Daily ETL',  
    @step_id = 1,
    @subsystem = N'TSQL',  
    @command = N'DECLARE @Yesterday DATE = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE);
EXEC dbo.usp_MasterETLProcess @InitialLoad = 0, @LoadDate = @Yesterday;',
    @database_name = N'WideWorldImportersDW',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2,     -- Quit with failure
    @retry_attempts = 2,
    @retry_interval = 5;     -- 5 minutes
GO

-- Add Step 2: Verify Data Load
EXEC sp_add_jobstep  
    @job_name = N'Daily_ETL_WideWorldImportersDW',  
    @step_name = N'Verify Data Load',  
    @step_id = 2,
    @subsystem = N'TSQL',  
    @command = N'DECLARE @Yesterday DATE = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE);
DECLARE @DateKey INT = CONVERT(INT, CONVERT(VARCHAR, @Yesterday, 112));
DECLARE @RowCount INT;

SELECT @RowCount = COUNT(*) FROM dbo.FactSales WHERE DateKey = @DateKey;

IF @RowCount = 0
BEGIN
    RAISERROR(''No data loaded for yesterday. ETL may have failed.'', 16, 1);
END
ELSE
BEGIN
    PRINT ''Successfully loaded '' + CAST(@RowCount AS VARCHAR(10)) + '' rows for '' + CAST(@Yesterday AS VARCHAR(10));
END',
    @database_name = N'WideWorldImportersDW',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;     -- Quit with failure
GO

-- Create schedule: Daily at 2:00 AM
EXEC sp_add_schedule  
    @schedule_name = N'Daily_2AM_Schedule',  
    @freq_type = 4,              -- Daily
    @freq_interval = 1,          -- Every day
    @active_start_time = 020000; -- 02:00:00 AM
GO

-- Attach schedule to job
EXEC sp_attach_schedule  
    @job_name = N'Daily_ETL_WideWorldImportersDW',  
    @schedule_name = N'Daily_2AM_Schedule';
GO

-- Add job to local server
EXEC dbo.sp_add_jobserver  
    @job_name = N'Daily_ETL_WideWorldImportersDW',
    @server_name = N'(local)';
GO

PRINT 'SQL Server Agent Job created successfully';
PRINT 'Job Name: Daily_ETL_WideWorldImportersDW';
PRINT 'Schedule: Daily at 2:00 AM';
PRINT '';
PRINT 'To run the job manually:';
PRINT 'EXEC msdb.dbo.sp_start_job @job_name = N''Daily_ETL_WideWorldImportersDW'';';
GO
