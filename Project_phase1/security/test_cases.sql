/*
    HRTrainingOps - Phase II
    Script : test_cases.sql
    Purpose: Simulate user workflows + verify role permissions
    Owner  : Dhruv (Security & Optimization Lead)

    Prerequisites:
      1. Phase I schema deployed
      2. Phase II objects deployed (functions, views, triggers, procedures)
      3. security/permissions.sql executed
      4. AdventureWorks2022 has HumanResources employees

    Run as dbo / sysadmin unless a section says EXECUTE AS.
*/
USE AdventureWorks2022;
GO

SET NOCOUNT ON;
PRINT '========== HRTrainingOps Phase II — Test Cases ==========';
GO

/* =========================================================
   0) Seed minimal catalog + sample enrollments (idempotent)
   ========================================================= */
PRINT '--- 0) Seed courses and sample data ---';
GO

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'SAFETY01')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'SAFETY01', N'Workplace Safety Basics', 12, 1);

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'HRCOMP02')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'HRCOMP02', N'HR Compliance Essentials', 24, 1);

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'LEAD03')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'LEAD03', N'Leadership Fundamentals', 18, 0);
GO

/* Department requirements — Production (7) and Sales (3) if present */
IF EXISTS (SELECT 1 FROM HumanResources.Department WHERE DepartmentID = 7)
AND NOT EXISTS (
    SELECT 1 FROM HRTrainingOps.DepartmentTrainingRequirement
    WHERE DepartmentID = 7 AND CourseCode = N'SAFETY01'
)
    INSERT INTO HRTrainingOps.DepartmentTrainingRequirement (DepartmentID, CourseCode, IsRequired)
    VALUES (7, N'SAFETY01', 1);

IF EXISTS (SELECT 1 FROM HumanResources.Department WHERE DepartmentID = 3)
AND NOT EXISTS (
    SELECT 1 FROM HRTrainingOps.DepartmentTrainingRequirement
    WHERE DepartmentID = 3 AND CourseCode = N'HRCOMP02'
)
    INSERT INTO HRTrainingOps.DepartmentTrainingRequirement (DepartmentID, CourseCode, IsRequired)
    VALUES (3, N'HRCOMP02', 1);
GO

/* Use well-known AdventureWorks employee 288 if present */
DECLARE @Emp288 INT = 288;
IF EXISTS (SELECT 1 FROM HumanResources.Employee WHERE BusinessEntityID = @Emp288 AND CurrentFlag = 1)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM HRTrainingOps.TrainingRequests
        WHERE BusinessEmployeeID = @Emp288 AND CourseCode = N'SAFETY01'
          AND RequestStatus IN (N'Pending', N'Completed')
    )
    BEGIN
        DECLARE @NewID INT;
        EXEC HRTrainingOps.usp_EnrollEmployeeInCourse
            @BusinessEmployeeID = @Emp288,
            @CourseCode = N'SAFETY01',
            @EnrollmentDate = '2024-01-15',
            @DepartmentID = NULL,
            @NewTrainingRequestID = @NewID OUTPUT;

        PRINT 'Seeded enrollment for employee 288. TrainingRequestID=' + CAST(@NewID AS NVARCHAR(20));

        /* Complete with a past expiry so batch/queue tests have data */
        UPDATE HRTrainingOps.TrainingRequests
        SET ExamDate = '2024-02-01',
            Score = 88.00,
            CertificationExpiryDate = '2024-06-01',
            RequestStatus = N'Completed'
        WHERE TrainingRequestID = @NewID;
    END
END
ELSE
    PRINT 'WARNING: Employee 288 not found — some self-service tests may be skipped.';
GO

/* =========================================================
   1) Workflow 1 — Enrollment (transaction + trigger)
   ========================================================= */
PRINT '--- 1) Workflow 1: Enroll employee ---';
GO

DECLARE @EmpID INT;
DECLARE @ReqID INT;

SELECT TOP (1) @EmpID = e.BusinessEntityID
FROM HumanResources.Employee AS e
WHERE e.CurrentFlag = 1
  AND NOT EXISTS (
        SELECT 1
        FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'LEAD03'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID;

IF @EmpID IS NOT NULL
BEGIN
    EXEC HRTrainingOps.usp_EnrollEmployeeInCourse
        @BusinessEmployeeID = @EmpID,
        @CourseCode = N'LEAD03',
        @EnrollmentDate = NULL,
        @DepartmentID = NULL,
        @NewTrainingRequestID = @ReqID OUTPUT;

    PRINT 'Enrolled employee ' + CAST(@EmpID AS NVARCHAR(20))
        + N' in LEAD03. RequestID=' + CAST(@ReqID AS NVARCHAR(20));

    SELECT * FROM HRTrainingOps.fn_GetEmployeeTrainingData(@EmpID);
    SELECT TOP (3) * FROM HRTrainingOps.NotificationLog
    WHERE BusinessEmployeeID = @EmpID
    ORDER BY NotificationID DESC;
END
ELSE
    PRINT 'No eligible employee found for LEAD03 enrollment test.';
GO

/* Negative test: future enrollment date should fail */
PRINT '--- 1b) Negative: future EnrollmentDate ---';
GO
BEGIN TRY
    DECLARE @BadID INT;
    DECLARE @AnyEmp INT;
    SELECT TOP (1) @AnyEmp = BusinessEntityID FROM HumanResources.Employee WHERE CurrentFlag = 1;

    EXEC HRTrainingOps.usp_EnrollEmployeeInCourse
        @BusinessEmployeeID = @AnyEmp,
        @CourseCode = N'HRCOMP02',
        @EnrollmentDate = '2099-01-01',
        @DepartmentID = NULL,
        @NewTrainingRequestID = @BadID OUTPUT;

    PRINT 'ERROR: future enrollment should have failed.';
END TRY
BEGIN CATCH
    PRINT 'Expected failure caught: ' + ERROR_MESSAGE();
END CATCH;
GO

/* =========================================================
   2) Workflow 2 — Expire batch + static cursor + review
   ========================================================= */
PRINT '--- 2) Workflow 2: Batch expire + static cursor + review ---';
GO

DECLARE @Queued INT;
EXEC HRTrainingOps.usp_BatchUpdateExpiredCertifications
    @AsOfDate = NULL,
    @RowsQueued = @Queued OUTPUT;
PRINT 'Rows queued: ' + CAST(@Queued AS NVARCHAR(20));

DECLARE @Processed INT;
EXEC HRTrainingOps.usp_ProcessExpiryQueueWithCursor
    @ProcessedCount = @Processed OUTPUT;
PRINT 'Static cursor processed: ' + CAST(@Processed AS NVARCHAR(20));

SELECT TOP (10) QueueID, TrainingRequestID, CourseCode, QueueStatus, DaysOverdue
FROM HRTrainingOps.ExpiredCertificationQueue
ORDER BY QueueID DESC;
GO

/* Process one review as Manager */
DECLARE @ReviewQueueID INT;
SELECT TOP (1) @ReviewQueueID = QueueID
FROM HRTrainingOps.ExpiredCertificationQueue
WHERE QueueStatus IN (N'Pending Review', N'Notified')
ORDER BY QueueID DESC;

IF @ReviewQueueID IS NOT NULL
BEGIN
    EXEC HRTrainingOps.usp_ProcessCertificationReview
        @QueueID = @ReviewQueueID,
        @ReviewDecision = N'Re-Enroll',
        @ReviewNotes = N'Test case: require re-enrollment after expiry.',
        @ReviewedBy = N'HR_Manager_Test';

    PRINT 'Reviewed QueueID=' + CAST(@ReviewQueueID AS NVARCHAR(20));

    SELECT TOP (5) * FROM HRTrainingOps.CertificationReleaseReview ORDER BY ReviewID DESC;
    SELECT TOP (5) ErrorLogID, LogCategory, ErrorMessage, LoggedDate
    FROM HRTrainingOps.ErrorLog
    WHERE LogCategory = N'Audit'
    ORDER BY ErrorLogID DESC;
END
ELSE
    PRINT 'No queue items available for review test.';
GO

/* =========================================================
   3) Workflow 3 — Dynamic SQL compliance + dynamic cursor
   ========================================================= */
PRINT '--- 3) Workflow 3: Compliance report (dynamic SQL) ---';
GO

EXEC HRTrainingOps.usp_RunComplianceReport
    @DepartmentName = NULL,
    @CourseCode = N'SAFETY01',
    @FromDate = '2020-01-01',
    @ToDate = NULL;
GO

EXEC HRTrainingOps.usp_GetDepartmentTrainingStats @DepartmentID = NULL;
GO

DECLARE @NotifyCount INT;
EXEC HRTrainingOps.usp_DynamicDepartmentNotification
    @DepartmentName = NULL,
    @NotificationsCreated = @NotifyCount OUTPUT;
PRINT 'Dynamic cursor notifications created: ' + CAST(@NotifyCount AS NVARCHAR(20));
GO

/* =========================================================
   4) Views + scalar function smoke tests
   ========================================================= */
PRINT '--- 4) Views and functions ---';
GO

SELECT TOP (10) * FROM HRTrainingOps.vEmployeeTrainingSummary;
SELECT TOP (10) * FROM HRTrainingOps.vw_PendingCertifications;
SELECT HRTrainingOps.fn_TrainingScoreClass(95) AS PassClass;
SELECT HRTrainingOps.fn_TrainingScoreClass(60) AS ConditionalClass;
SELECT HRTrainingOps.fn_TrainingScoreClass(40) AS FailClass;
GO

EXEC HRTrainingOps.usp_GetTrainingRequests
    @RequestStatus = N'Pending',
    @CourseCode = NULL,
    @BusinessEmployeeID = NULL;
GO

/* =========================================================
   5) Permission tests (EXECUTE AS)
   ========================================================= */
PRINT '--- 5a) Training_Clerk MAY enroll ---';
GO
BEGIN TRY
    EXECUTE AS USER = N'HRTO_Clerk';

    DECLARE @ClerkReq INT;
    DECLARE @ClerkEmp INT;
    SELECT TOP (1) @ClerkEmp = e.BusinessEntityID
    FROM HumanResources.Employee AS e
    WHERE e.CurrentFlag = 1
      AND NOT EXISTS (
            SELECT 1 FROM HRTrainingOps.TrainingRequests tr
            WHERE tr.BusinessEmployeeID = e.BusinessEntityID
              AND tr.CourseCode = N'HRCOMP02'
              AND tr.RequestStatus IN (N'Pending', N'Completed')
          );

    IF @ClerkEmp IS NOT NULL
    BEGIN
        EXEC HRTrainingOps.usp_EnrollEmployeeInCourse
            @BusinessEmployeeID = @ClerkEmp,
            @CourseCode = N'HRCOMP02',
            @EnrollmentDate = NULL,
            @DepartmentID = NULL,
            @NewTrainingRequestID = @ClerkReq OUTPUT;
        PRINT 'Clerk enrollment OK. RequestID=' + CAST(@ClerkReq AS NVARCHAR(20));
    END
    ELSE
        PRINT 'Clerk enrollment skipped — no eligible employee.';

    REVERT;
END TRY
BEGIN CATCH
    PRINT 'Clerk enroll unexpected error: ' + ERROR_MESSAGE();
    IF EXISTS (SELECT 1 FROM sys.dm_exec_sessions WHERE session_id = @@SPID AND original_login_name <> SUSER_SNAME())
        OR USER_NAME() <> ORIGINAL_LOGIN()
        REVERT;
END CATCH;
GO

PRINT '--- 5b) Training_Clerk DENIED review procedure ---';
GO
BEGIN TRY
    EXECUTE AS USER = N'HRTO_Clerk';
    EXEC HRTrainingOps.usp_ProcessCertificationReview
        @QueueID = 1,
        @ReviewDecision = N'Waived',
        @ReviewNotes = N'Should fail',
        @ReviewedBy = N'Clerk';
    PRINT 'ERROR: Clerk should not execute review procedure.';
    REVERT;
END TRY
BEGIN CATCH
    PRINT 'Expected DENY for Clerk: ' + ERROR_MESSAGE();
    BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;
END CATCH;
GO

PRINT '--- 5c) Employee_Client self-service only ---';
GO
BEGIN TRY
    EXECUTE AS USER = N'HRTO_Emp_288';

    SELECT * FROM HRTrainingOps.vw_EmployeeSelfService;

    BEGIN TRY
        SELECT TOP (1) * FROM HRTrainingOps.TrainingRequests;
        PRINT 'ERROR: Employee should be denied direct table SELECT.';
    END TRY
    BEGIN CATCH
        PRINT 'Expected DENY on TrainingRequests: ' + ERROR_MESSAGE();
    END CATCH;

    REVERT;
END TRY
BEGIN CATCH
    PRINT 'Employee self-service error: ' + ERROR_MESSAGE();
    BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;
END CATCH;
GO

PRINT '--- 5d) Manager may run compliance report ---';
GO
BEGIN TRY
    EXECUTE AS USER = N'HRTO_Manager';
    EXEC HRTrainingOps.usp_RunComplianceReport @CourseCode = N'SAFETY01';
    SELECT TOP (5) * FROM HRTrainingOps.vw_ManagerDepartmentCompliance;
    REVERT;
    PRINT 'Manager compliance OK.';
END TRY
BEGIN CATCH
    PRINT 'Manager test error: ' + ERROR_MESSAGE();
    BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;
END CATCH;
GO

PRINT '--- 5e) Clerk DENIED DELETE on TrainingRequests ---';
GO
BEGIN TRY
    EXECUTE AS USER = N'HRTO_Clerk';
    /* DENY DELETE raises even when zero rows match */
    DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = -1;
    PRINT 'ERROR: Clerk DELETE should be denied.';
    REVERT;
END TRY
BEGIN CATCH
    PRINT 'Expected DENY DELETE for Clerk: ' + ERROR_MESSAGE();
    BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;
END CATCH;
GO

PRINT '========== Phase II test cases complete ==========';
GO
