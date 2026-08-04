/*
    HRTrainingOps - Phase II
    Script : usp_EnrollEmployeeInCourse.sql
    Purpose: Enroll an active employee in a course (transaction + TRY/CATCH)
    Owner  : Parth Patel (Logic Developer)
    Workflow 1
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_EnrollEmployeeInCourse', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_EnrollEmployeeInCourse;
GO

CREATE PROCEDURE HRTrainingOps.usp_EnrollEmployeeInCourse
    @BusinessEmployeeID INT,
    @CourseCode         NVARCHAR(10),
    @EnrollmentDate     DATE = NULL,
    @DepartmentID       SMALLINT = NULL,
    @NewTrainingRequestID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @LocalEnrollmentDate DATE = ISNULL(@EnrollmentDate, CAST(SYSDATETIME() AS DATE));
    DECLARE @ResolvedDepartmentID SMALLINT = @DepartmentID;

    SET @NewTrainingRequestID = NULL;

    BEGIN TRY
        IF @BusinessEmployeeID IS NULL OR @CourseCode IS NULL
            THROW 51001, 'BusinessEmployeeID and CourseCode are required.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM HumanResources.Employee
            WHERE BusinessEntityID = @BusinessEmployeeID
              AND CurrentFlag = 1
        )
            THROW 51002, 'Employee not found or is not active.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingCourse
            WHERE CourseCode = @CourseCode
        )
            THROW 51003, 'CourseCode does not exist.', 1;

        IF @LocalEnrollmentDate > CAST(SYSDATETIME() AS DATE)
            THROW 51004, 'EnrollmentDate cannot be in the future.', 1;

        IF EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests
            WHERE BusinessEmployeeID = @BusinessEmployeeID
              AND CourseCode = @CourseCode
              AND RequestStatus IN (N'Pending', N'Completed')
        )
            THROW 51005, 'Employee already has an active enrollment for this course.', 1;

        IF @ResolvedDepartmentID IS NULL
        BEGIN
            SELECT TOP (1) @ResolvedDepartmentID = edh.DepartmentID
            FROM HumanResources.EmployeeDepartmentHistory AS edh
            WHERE edh.BusinessEntityID = @BusinessEmployeeID
              AND edh.EndDate IS NULL
            ORDER BY edh.StartDate DESC;
        END;

        BEGIN TRANSACTION;

        INSERT INTO HRTrainingOps.TrainingRequests
            (BusinessEmployeeID, CourseCode, EnrollmentDate, RequestStatus, DepartmentID)
        VALUES
            (@BusinessEmployeeID, @CourseCode, @LocalEnrollmentDate, N'Pending', @ResolvedDepartmentID);

        SET @NewTrainingRequestID = SCOPE_IDENTITY();

        INSERT INTO HRTrainingOps.NotificationLog
            (BusinessEmployeeID, NotificationType, MessageText)
        VALUES
            (@BusinessEmployeeID,
             N'Enrollment Confirmation',
             N'Enrolled in course ' + @CourseCode + N' on ' + CONVERT(NVARCHAR(10), @LocalEnrollmentDate, 120)
             + N'. RequestID=' + CAST(@NewTrainingRequestID AS NVARCHAR(20)));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_PROCEDURE(), ERROR_LINE(), N'Error');

        THROW;
    END CATCH;
END;
GO

PRINT 'Procedure HRTrainingOps.usp_EnrollEmployeeInCourse created.';
GO

/* ========== TEST CASE ========== */
PRINT '--- TEST: usp_EnrollEmployeeInCourse ---';
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'TESTENR01')
        INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
        VALUES (N'TESTENR01', N'Enrollment Proc Test Course', 12, 0);

    DECLARE @EmpID INT;
    DECLARE @NewID INT;

    SELECT TOP (1) @EmpID = e.BusinessEntityID
    FROM HumanResources.Employee AS e
    WHERE e.CurrentFlag = 1
      AND NOT EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests AS tr
            WHERE tr.BusinessEmployeeID = e.BusinessEntityID
              AND tr.CourseCode = N'TESTENR01'
              AND tr.RequestStatus IN (N'Pending', N'Completed')
          )
    ORDER BY e.BusinessEntityID;

    IF @EmpID IS NULL
        PRINT 'TEST RESULT: SKIP — no free employee available.';
    ELSE
    BEGIN
        EXEC HRTrainingOps.usp_EnrollEmployeeInCourse
            @BusinessEmployeeID = @EmpID,
            @CourseCode = N'TESTENR01',
            @EnrollmentDate = NULL,
            @DepartmentID = NULL,
            @NewTrainingRequestID = @NewID OUTPUT;

        IF @NewID IS NOT NULL
            PRINT 'TEST RESULT: PASS — enrolled TrainingRequestID=' + CAST(@NewID AS NVARCHAR(20));
        ELSE
            PRINT 'TEST RESULT: FAIL — no TrainingRequestID returned.';

        DELETE FROM HRTrainingOps.NotificationLog
        WHERE BusinessEmployeeID = @EmpID
          AND NotificationType = N'Enrollment Confirmation'
          AND MessageText LIKE N'%TESTENR01%';

        DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = @NewID;
    END
END TRY
BEGIN CATCH
    PRINT 'TEST RESULT: FAIL — ' + ERROR_MESSAGE();
END CATCH;
GO
