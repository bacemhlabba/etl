/*
    Stored Procedure: usp_LoadDimDate
    Purpose: Populate the Date dimension table
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_LoadDimDate', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadDimDate;
GO

CREATE PROCEDURE dbo.usp_LoadDimDate
    @StartDate DATE = '2013-01-01',
    @EndDate DATE = '2025-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentDate DATE = @StartDate;
    
    -- Clear existing data
    TRUNCATE TABLE dbo.DimDate;
    
    -- Populate date dimension
    WHILE @CurrentDate <= @EndDate
    BEGIN
        INSERT INTO dbo.DimDate (
            DateKey,
            Date,
            DayOfMonth,
            DaySuffix,
            DayName,
            DayOfWeek,
            DayOfWeekInMonth,
            DayOfYear,
            WeekOfMonth,
            WeekOfYear,
            Month,
            MonthName,
            Quarter,
            QuarterName,
            Year,
            IsWeekend,
            IsHoliday
        )
        VALUES (
            CONVERT(INT, CONVERT(VARCHAR, @CurrentDate, 112)),  -- DateKey: YYYYMMDD
            @CurrentDate,                                        -- Date
            DAY(@CurrentDate),                                   -- DayOfMonth
            CASE 
                WHEN DAY(@CurrentDate) IN (1, 21, 31) THEN 'st'
                WHEN DAY(@CurrentDate) IN (2, 22) THEN 'nd'
                WHEN DAY(@CurrentDate) IN (3, 23) THEN 'rd'
                ELSE 'th'
            END,                                                 -- DaySuffix
            DATENAME(WEEKDAY, @CurrentDate),                     -- DayName
            DATEPART(WEEKDAY, @CurrentDate),                     -- DayOfWeek
            CEILING(DAY(@CurrentDate) / 7.0),                    -- DayOfWeekInMonth
            DATEPART(DAYOFYEAR, @CurrentDate),                   -- DayOfYear
            CEILING(DAY(@CurrentDate) / 7.0),                    -- WeekOfMonth
            DATEPART(WEEK, @CurrentDate),                        -- WeekOfYear
            MONTH(@CurrentDate),                                 -- Month
            DATENAME(MONTH, @CurrentDate),                       -- MonthName
            DATEPART(QUARTER, @CurrentDate),                     -- Quarter
            'Q' + CAST(DATEPART(QUARTER, @CurrentDate) AS VARCHAR(1)), -- QuarterName
            YEAR(@CurrentDate),                                  -- Year
            CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END, -- IsWeekend
            0                                                    -- IsHoliday (default)
        );
        
        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END
    
    PRINT 'DimDate loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows inserted';
END
GO

PRINT 'Stored Procedure usp_LoadDimDate created successfully';
GO
