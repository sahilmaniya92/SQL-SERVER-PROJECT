/*
    HRTrainingOps - Phase II
    Script : vw_EmployeeSelfService.sql
    Purpose: Employee_Client sees only own training records
             Demo logins: HRTO_Emp_<BusinessEntityID>  (e.g. HRTO_Emp_288)
             HR_Admin / dbo see all rows.
    Owner  : Sahil Maniya (Schema Designer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.vw_EmployeeSelfService', N'V') IS NOT NULL
    DROP VIEW HRTrainingOps.vw_EmployeeSelfService;
GO

CREATE VIEW HRTrainingOps.vw_EmployeeSelfService
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
    tr.Score,
    HRTrainingOps.fn_TrainingScoreClass(tr.Score) AS ScoreClass,
    tr.CertificationExpiryDate,
    tr.RequestStatus,
    tr.DepartmentID
FROM HRTrainingOps.TrainingRequests AS tr
INNER JOIN HRTrainingOps.TrainingCourse AS tc
    ON tc.CourseCode = tr.CourseCode
INNER JOIN Person.Person AS p
    ON p.BusinessEntityID = tr.BusinessEmployeeID
WHERE IS_MEMBER(N'HR_Admin') = 1
   OR IS_SRVROLEMEMBER(N'sysadmin') = 1
   OR USER_NAME() = N'dbo'
   OR tr.BusinessEmployeeID = TRY_CAST(
            SUBSTRING(
                SUSER_SNAME(),
                NULLIF(CHARINDEX(N'_Emp_', SUSER_SNAME()), 0) + 5,
                10
            ) AS INT
        );
GO

PRINT 'View HRTrainingOps.vw_EmployeeSelfService created.';
GO
