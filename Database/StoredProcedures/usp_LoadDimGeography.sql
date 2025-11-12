/*
    Stored Procedure: usp_LoadDimGeography
    Purpose: Load Geography dimension from source database (Type 1 SCD)
    Author: ETL Project
    Date: 2025-11-12
*/

USE WideWorldImportersDW;
GO

IF OBJECT_ID('dbo.usp_LoadDimGeography', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LoadDimGeography;
GO

CREATE PROCEDURE dbo.usp_LoadDimGeography
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    
    -- Merge data from source
    MERGE dbo.DimGeography AS Target
    USING (
        SELECT 
            c.CityID,
            c.CityName,
            sp.StateProvinceID,
            sp.StateProvinceName,
            sp.StateProvinceCode,
            co.CountryID,
            co.CountryName,
            co.Continent,
            co.Region,
            co.Subregion,
            c.LatestRecordedPopulation
        FROM WideWorldImporters.Application.Cities c
        INNER JOIN WideWorldImporters.Application.StateProvinces sp ON c.StateProvinceID = sp.StateProvinceID
        INNER JOIN WideWorldImporters.Application.Countries co ON sp.CountryID = co.CountryID
    ) AS Source
    ON Target.CityID = Source.CityID
    
    -- Update existing records (Type 1 SCD - overwrite)
    WHEN MATCHED AND (
        Target.CityName <> Source.CityName OR
        Target.StateProvinceName <> Source.StateProvinceName OR
        Target.CountryName <> Source.CountryName OR
        Target.LatestRecordedPopulation <> Source.LatestRecordedPopulation OR
        (Target.LatestRecordedPopulation IS NULL AND Source.LatestRecordedPopulation IS NOT NULL) OR
        (Target.LatestRecordedPopulation IS NOT NULL AND Source.LatestRecordedPopulation IS NULL)
    ) THEN
        UPDATE SET
            Target.CityName = Source.CityName,
            Target.StateProvinceID = Source.StateProvinceID,
            Target.StateProvinceName = Source.StateProvinceName,
            Target.StateProvinceCode = Source.StateProvinceCode,
            Target.CountryID = Source.CountryID,
            Target.CountryName = Source.CountryName,
            Target.Continent = Source.Continent,
            Target.Region = Source.Region,
            Target.Subregion = Source.Subregion,
            Target.LatestRecordedPopulation = Source.LatestRecordedPopulation
    
    -- Insert new records
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (
            CityID,
            CityName,
            StateProvinceID,
            StateProvinceName,
            StateProvinceCode,
            CountryID,
            CountryName,
            Continent,
            Region,
            Subregion,
            LatestRecordedPopulation
        )
        VALUES (
            Source.CityID,
            Source.CityName,
            Source.StateProvinceID,
            Source.StateProvinceName,
            Source.StateProvinceCode,
            Source.CountryID,
            Source.CountryName,
            Source.Continent,
            Source.Region,
            Source.Subregion,
            Source.LatestRecordedPopulation
        );
    
    SET @RowsInserted = @@ROWCOUNT;
    
    PRINT 'DimGeography loaded: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows affected';
END
GO

PRINT 'Stored Procedure usp_LoadDimGeography created successfully';
GO
