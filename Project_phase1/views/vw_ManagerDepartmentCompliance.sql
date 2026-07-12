/*
    HRTrainingOps - Phase II
    Script : vw_ManagerDepartmentCompliance.sql
    Purpose: Row-level department filter for HR_Manager role
             Demo logins: HRTO_Mgr_<DepartmentID>  (e.g. HRTO_Mgr_7)
             HR_Admin / dbo see all departments.
    Owner  : Sahil Maniya (Schema Designer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.vw_ManagerDepartmentCompliance', N'V') IS NOT NULL
    DROP VIEW HRTrainingOps.vw_ManagerDepartmentCompliance;
GO

CREATE VIEW HRTrainingOps.vw_ManagerDepartmentCompliance
AS
SELECT
    req.DepartmentID,
    d.Name AS DepartmentName,
    req.CourseCode,
    tc.CourseName,
    tc.IsMandatory,
    req.IsRequired,
    emp.BusinessEntityID AS BusinessEmployeeID,
    p.FirstName,
    p.LastName,
    tr.TrainingRequestID,
    tr.RequestStatus,
    tr.ExamDate,
    tr.Score,
    tr.CertificationExpiryDate,
    CASE
        WHEN tr.TrainingRequestID IS NULL THEN N'Missing Enrollment'
        WHEN tr.RequestStatus = N'Expired' THEN N'Expired'
        WHEN tr.RequestStatus = N'Failed' THEN N'Failed'
        WHEN tr.RequestStatus = N'Pending' THEN N'In Progress'
        WHEN tr.RequestStatus = N'Completed'
             AND tr.CertificationExpiryDate < CAST(SYSDATETIME() AS DATE) THEN N'Expired'
        WHEN tr.RequestStatus = N'Completed' THEN N'Compliant'
        ELSE N'Unknown'
    END AS ComplianceStatus
FROM HRTrainingOps.DepartmentTrainingRequirement AS req
INNER JOIN HumanResources.Department AS d
    ON d.DepartmentID = req.DepartmentID
INNER JOIN HRTrainingOps.TrainingCourse AS tc
    ON tc.CourseCode = req.CourseCode
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.DepartmentID = req.DepartmentID
   AND edh.EndDate IS NULL
INNER JOIN HumanResources.Employee AS emp
    ON emp.BusinessEntityID = edh.BusinessEntityID
   AND emp.CurrentFlag = 1
INNER JOIN Person.Person AS p
    ON p.BusinessEntityID = emp.BusinessEntityID
LEFT JOIN HRTrainingOps.TrainingRequests AS tr
    ON tr.BusinessEmployeeID = emp.BusinessEntityID
   AND tr.CourseCode = req.CourseCode
   AND tr.RequestStatus IN (N'Pending', N'Completed', N'Expired', N'Failed')
WHERE req.IsRequired = 1
  AND (
        IS_MEMBER(N'HR_Admin') = 1
        OR IS_SRVROLEMEMBER(N'sysadmin') = 1
        OR USER_NAME() = N'dbo'
        OR req.DepartmentID = TRY_CAST(
                SUBSTRING(
                    SUSER_SNAME(),
                    NULLIF(CHARINDEX(N'_Mgr_', SUSER_SNAME()), 0) + 5,
                    10
                ) AS SMALLINT
            )
      );
GO

PRINT 'View HRTrainingOps.vw_ManagerDepartmentCompliance created.';
GO
