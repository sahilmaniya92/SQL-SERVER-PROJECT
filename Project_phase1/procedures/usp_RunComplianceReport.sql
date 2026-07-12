/*
    HRTrainingOps - Phase II
    Script : usp_RunComplianceReport.sql
    Purpose: DYNAMIC SQL compliance report filtered by department, course, and/or date
             Uses sp_executesql parameterization (no string concatenation of values)
    Owner  : Dhruv (Security & Optimization Lead)
    Workflow 3
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_RunComplianceReport', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_RunComplianceReport;
GO

CREATE PROCEDURE HRTrainingOps.usp_RunComplianceReport
    @DepartmentName NVARCHAR(50) = NULL,
    @CourseCode     NVARCHAR(10) = NULL,
    @FromDate       DATE = NULL,
    @ToDate         DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @where NVARCHAR(MAX) = N' WHERE 1 = 1';

    BEGIN TRY
        IF @FromDate IS NOT NULL AND @ToDate IS NOT NULL AND @FromDate > @ToDate
            THROW 51301, 'FromDate cannot be later than ToDate.', 1;

        SET @sql = N'
SELECT
    d.DepartmentID,
    d.Name AS DepartmentName,
    tr.CourseCode,
    tc.CourseName,
    tr.BusinessEmployeeID,
    p.FirstName,
    p.LastName,
    tr.EnrollmentDate,
    tr.ExamDate,
    tr.Score,
    tr.CertificationExpiryDate,
    tr.RequestStatus,
    CASE
        WHEN tr.RequestStatus = N''Completed''
             AND tr.CertificationExpiryDate >= CAST(SYSDATETIME() AS DATE)
            THEN N''Compliant''
        WHEN tr.RequestStatus = N''Pending'' THEN N''In Progress''
        WHEN tr.RequestStatus = N''Expired'' THEN N''Non-Compliant''
        WHEN tr.RequestStatus = N''Failed'' THEN N''Non-Compliant''
        ELSE N''Review''
    END AS ComplianceFlag
FROM HRTrainingOps.TrainingRequests AS tr
INNER JOIN HRTrainingOps.TrainingCourse AS tc
    ON tc.CourseCode = tr.CourseCode
INNER JOIN Person.Person AS p
    ON p.BusinessEntityID = tr.BusinessEmployeeID
LEFT JOIN HumanResources.Department AS d
    ON d.DepartmentID = tr.DepartmentID';

        IF @DepartmentName IS NOT NULL
            SET @where += N' AND d.Name = @pDepartmentName';

        IF @CourseCode IS NOT NULL
            SET @where += N' AND tr.CourseCode = @pCourseCode';

        IF @FromDate IS NOT NULL
            SET @where += N' AND tr.EnrollmentDate >= @pFromDate';

        IF @ToDate IS NOT NULL
            SET @where += N' AND tr.EnrollmentDate <= @pToDate';

        SET @sql += @where + N'
ORDER BY d.Name, tr.CourseCode, p.LastName, p.FirstName;';

        EXEC sys.sp_executesql
            @sql,
            N'@pDepartmentName NVARCHAR(50), @pCourseCode NVARCHAR(10), @pFromDate DATE, @pToDate DATE',
            @pDepartmentName = @DepartmentName,
            @pCourseCode = @CourseCode,
            @pFromDate = @FromDate,
            @pToDate = @ToDate;
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

PRINT 'Procedure HRTrainingOps.usp_RunComplianceReport created.';
GO
