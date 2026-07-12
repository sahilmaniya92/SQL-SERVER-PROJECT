/*
    HRTrainingOps - Phase II
    Script : vw_PendingCertifications.sql
    Purpose: Pending exams and certifications awaiting renewal/action
    Owner  : Sahil Maniya (Schema Designer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.vw_PendingCertifications', N'V') IS NOT NULL
    DROP VIEW HRTrainingOps.vw_PendingCertifications;
GO

CREATE VIEW HRTrainingOps.vw_PendingCertifications
AS
SELECT
    tr.TrainingRequestID,
    tr.BusinessEmployeeID,
    p.FirstName,
    p.LastName,
    tr.CourseCode,
    tc.CourseName,
    tr.EnrollmentDate,
    tr.ExamDate,
    tr.CertificationExpiryDate,
    tr.RequestStatus,
    tr.DepartmentID,
    d.Name AS DepartmentName,
    CASE
        WHEN tr.RequestStatus = N'Pending' THEN N'Awaiting Exam'
        WHEN tr.RequestStatus = N'Expired' THEN N'Renewal Required'
        WHEN tr.CertificationExpiryDate IS NOT NULL
             AND tr.CertificationExpiryDate <= DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE))
            THEN N'Expiring Within 30 Days'
        ELSE N'Review Needed'
    END AS ActionNeeded
FROM HRTrainingOps.TrainingRequests AS tr
INNER JOIN HRTrainingOps.TrainingCourse AS tc
    ON tc.CourseCode = tr.CourseCode
INNER JOIN Person.Person AS p
    ON p.BusinessEntityID = tr.BusinessEmployeeID
LEFT JOIN HumanResources.Department AS d
    ON d.DepartmentID = tr.DepartmentID
WHERE tr.RequestStatus IN (N'Pending', N'Expired')
   OR (
        tr.RequestStatus = N'Completed'
        AND tr.CertificationExpiryDate IS NOT NULL
        AND tr.CertificationExpiryDate <= DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE))
      );
GO

PRINT 'View HRTrainingOps.vw_PendingCertifications created.';
GO
