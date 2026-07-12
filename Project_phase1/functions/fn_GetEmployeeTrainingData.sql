/*
    HRTrainingOps - Phase II
    Script : fn_GetEmployeeTrainingData.sql
    Purpose: Inline TVF — return training rows for a given employee
    Owner  : Parth Patel (Logic Developer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.fn_GetEmployeeTrainingData', N'IF') IS NOT NULL
    DROP FUNCTION HRTrainingOps.fn_GetEmployeeTrainingData;
GO

CREATE FUNCTION HRTrainingOps.fn_GetEmployeeTrainingData
(
    @BusinessEmployeeID INT
)
RETURNS TABLE
AS
RETURN
(
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
    INNER JOIN HumanResources.Employee AS e
        ON e.BusinessEntityID = tr.BusinessEmployeeID
    INNER JOIN Person.Person AS p
        ON p.BusinessEntityID = e.BusinessEntityID
    LEFT JOIN HumanResources.Department AS d
        ON d.DepartmentID = tr.DepartmentID
    WHERE tr.BusinessEmployeeID = @BusinessEmployeeID
);
GO

PRINT 'Function HRTrainingOps.fn_GetEmployeeTrainingData created.';
GO
