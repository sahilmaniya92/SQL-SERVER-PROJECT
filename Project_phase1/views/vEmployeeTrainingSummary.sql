/*
    HRTrainingOps - Phase II
    Script : vEmployeeTrainingSummary.sql
    Purpose: Joined summary of employee training enrollments for reporting
    Owner  : Sahil Maniya (Schema Designer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.vEmployeeTrainingSummary', N'V') IS NOT NULL
    DROP VIEW HRTrainingOps.vEmployeeTrainingSummary;
GO

CREATE VIEW HRTrainingOps.vEmployeeTrainingSummary
AS
SELECT
    tr.TrainingRequestID,
    tr.BusinessEmployeeID,
    p.FirstName,
    p.LastName,
    e.JobTitle,
    tr.DepartmentID,
    d.Name AS DepartmentName,
    tr.CourseCode,
    tc.CourseName,
    tc.IsMandatory,
    tc.ValidityMonths,
    tr.EnrollmentDate,
    tr.ExamDate,
    tr.Score,
    HRTrainingOps.fn_TrainingScoreClass(tr.Score) AS ScoreClass,
    tr.CertificationExpiryDate,
    tr.RequestStatus,
    tr.CreatedDate,
    CASE
        WHEN tr.CertificationExpiryDate IS NULL THEN N'N/A'
        WHEN tr.CertificationExpiryDate < CAST(SYSDATETIME() AS DATE) THEN N'Expired'
        WHEN tr.CertificationExpiryDate <= DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE)) THEN N'Expiring Soon'
        ELSE N'Valid'
    END AS CertificationHealth
FROM HRTrainingOps.TrainingRequests AS tr
INNER JOIN HRTrainingOps.TrainingCourse AS tc
    ON tc.CourseCode = tr.CourseCode
INNER JOIN HumanResources.Employee AS e
    ON e.BusinessEntityID = tr.BusinessEmployeeID
INNER JOIN Person.Person AS p
    ON p.BusinessEntityID = e.BusinessEntityID
LEFT JOIN HumanResources.Department AS d
    ON d.DepartmentID = tr.DepartmentID;
GO

PRINT 'View HRTrainingOps.vEmployeeTrainingSummary created.';
GO
