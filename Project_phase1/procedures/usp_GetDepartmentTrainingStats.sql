/*
    HRTrainingOps - Phase II
    Script : usp_GetDepartmentTrainingStats.sql
    Purpose: Department-level training statistics report
    Owner  : Dhruv (Security & Optimization Lead)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_GetDepartmentTrainingStats', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_GetDepartmentTrainingStats;
GO

CREATE PROCEDURE HRTrainingOps.usp_GetDepartmentTrainingStats
    @DepartmentID SMALLINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRY
        SELECT
            d.DepartmentID,
            d.Name AS DepartmentName,
            COUNT(tr.TrainingRequestID) AS TotalEnrollments,
            SUM(CASE WHEN tr.RequestStatus = N'Pending' THEN 1 ELSE 0 END) AS PendingCount,
            SUM(CASE WHEN tr.RequestStatus = N'Completed' THEN 1 ELSE 0 END) AS CompletedCount,
            SUM(CASE WHEN tr.RequestStatus = N'Failed' THEN 1 ELSE 0 END) AS FailedCount,
            SUM(CASE WHEN tr.RequestStatus = N'Expired' THEN 1 ELSE 0 END) AS ExpiredCount,
            AVG(tr.Score) AS AverageScore,
            SUM(CASE
                    WHEN tr.RequestStatus = N'Completed'
                     AND tr.CertificationExpiryDate >= CAST(SYSDATETIME() AS DATE)
                    THEN 1 ELSE 0
                END) AS CurrentlyValidCerts
        FROM HumanResources.Department AS d
        LEFT JOIN HRTrainingOps.TrainingRequests AS tr
            ON tr.DepartmentID = d.DepartmentID
        WHERE (@DepartmentID IS NULL OR d.DepartmentID = @DepartmentID)
        GROUP BY d.DepartmentID, d.Name
        ORDER BY d.Name;
    END TRY
    BEGIN CATCH
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_PROCEDURE(), ERROR_LINE(), N'Error');

        THROW;
    END CATCH;
END;
GO

PRINT 'Procedure HRTrainingOps.usp_GetDepartmentTrainingStats created.';
GO
