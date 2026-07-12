/*
    HRTrainingOps - Phase II
    Script : usp_GetTrainingRequests.sql
    Purpose: Parameterized search of training requests by status and/or course
    Owner  : Parth Patel (Logic Developer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_GetTrainingRequests', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_GetTrainingRequests;
GO

CREATE PROCEDURE HRTrainingOps.usp_GetTrainingRequests
    @RequestStatus NVARCHAR(20) = NULL,
    @CourseCode    NVARCHAR(10) = NULL,
    @BusinessEmployeeID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    BEGIN TRY
        IF @RequestStatus IS NOT NULL
           AND @RequestStatus NOT IN (N'Pending', N'Completed', N'Failed', N'Expired')
            THROW 51101, 'Invalid RequestStatus. Use Pending, Completed, Failed, or Expired.', 1;

        SELECT
            tr.TrainingRequestID,
            tr.BusinessEmployeeID,
            p.FirstName,
            p.LastName,
            tr.CourseCode,
            tc.CourseName,
            tr.EnrollmentDate,
            tr.ExamDate,
            tr.Score,
            HRTrainingOps.fn_TrainingScoreClass(tr.Score) AS ScoreClass,
            tr.CertificationExpiryDate,
            tr.RequestStatus,
            tr.DepartmentID,
            d.Name AS DepartmentName
        FROM HRTrainingOps.TrainingRequests AS tr
        INNER JOIN HRTrainingOps.TrainingCourse AS tc
            ON tc.CourseCode = tr.CourseCode
        INNER JOIN Person.Person AS p
            ON p.BusinessEntityID = tr.BusinessEmployeeID
        LEFT JOIN HumanResources.Department AS d
            ON d.DepartmentID = tr.DepartmentID
        WHERE (@RequestStatus IS NULL OR tr.RequestStatus = @RequestStatus)
          AND (@CourseCode IS NULL OR tr.CourseCode = @CourseCode)
          AND (@BusinessEmployeeID IS NULL OR tr.BusinessEmployeeID = @BusinessEmployeeID)
        ORDER BY tr.EnrollmentDate DESC, tr.TrainingRequestID DESC;
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

PRINT 'Procedure HRTrainingOps.usp_GetTrainingRequests created.';
GO
