/*
    HRTrainingOps - Phase I
    Script : 01_create_schema.sql
    Purpose: Create the HRTrainingOps schema
  
*/
USE AdventureWorks2022;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'HRTrainingOps'
)
BEGIN
    EXEC(N'CREATE SCHEMA HRTrainingOps AUTHORIZATION dbo;');
    PRINT 'Schema HRTrainingOps created.';
END
ELSE
BEGIN
    PRINT 'Schema HRTrainingOps already exists.';
END
GO
