/*
    HRTrainingOps - Phase II
    Script : fn_TrainingScoreClass.sql
    Purpose: Scalar UDF — classify exam score as Pass / Conditional / Fail
    Owner  : Parth Patel (Logic Developer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.fn_TrainingScoreClass', N'FN') IS NOT NULL
    DROP FUNCTION HRTrainingOps.fn_TrainingScoreClass;
GO

CREATE FUNCTION HRTrainingOps.fn_TrainingScoreClass
(
    @Score DECIMAL(5, 2)
)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @Result NVARCHAR(20);

    IF @Score IS NULL
        SET @Result = N'Not Graded';
    ELSE IF @Score >= 70
        SET @Result = N'Pass';
    ELSE IF @Score >= 50
        SET @Result = N'Conditional';
    ELSE
        SET @Result = N'Fail';

    RETURN @Result;
END;
GO

PRINT 'Function HRTrainingOps.fn_TrainingScoreClass created.';
GO
