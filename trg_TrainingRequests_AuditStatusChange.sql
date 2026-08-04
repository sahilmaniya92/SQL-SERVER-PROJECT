/*
    HRTrainingOps - Phase II
    Script : trg_TrainingRequests_AuditStatusChange.sql
    Purpose: AFTER UPDATE — audit RequestStatus changes to ErrorLog (Audit)
    Owner  : Parth Patel (Logic Developer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.trg_TrainingRequests_AuditStatusChange', N'TR') IS NOT NULL
    DROP TRIGGER HRTrainingOps.trg_TrainingRequests_AuditStatusChange;
GO

CREATE TRIGGER HRTrainingOps.trg_TrainingRequests_AuditStatusChange
ON HRTrainingOps.TrainingRequests
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(RequestStatus)
    BEGIN
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        SELECT
            NULL,
            N'TrainingRequestID=' + CAST(i.TrainingRequestID AS NVARCHAR(20))
                + N' status changed from [' + ISNULL(d.RequestStatus, N'NULL') + N'] to ['
                + ISNULL(i.RequestStatus, N'NULL') + N'] by ' + SUSER_SNAME(),
            N'trg_TrainingRequests_AuditStatusChange',
            NULL,
            N'Audit'
        FROM inserted AS i
        INNER JOIN deleted AS d
            ON d.TrainingRequestID = i.TrainingRequestID
        WHERE ISNULL(i.RequestStatus, N'') <> ISNULL(d.RequestStatus, N'');
    END;
END;
GO

PRINT 'Trigger HRTrainingOps.trg_TrainingRequests_AuditStatusChange created.';
GO

/* ========== TEST CASE ========== */
PRINT '--- TEST: trg_TrainingRequests_AuditStatusChange ---';
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'TESTAUD01')
        INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
        VALUES (N'TESTAUD01', N'Trigger Audit Test Course', 12, 0);

    DECLARE @EmpID INT;
    DECLARE @ReqID INT;
    DECLARE @AuditBefore INT;
    DECLARE @AuditAfter INT;

    SELECT TOP (1) @EmpID = e.BusinessEntityID
    FROM HumanResources.Employee AS e
    WHERE e.CurrentFlag = 1
      AND NOT EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests AS tr
            WHERE tr.BusinessEmployeeID = e.BusinessEntityID
              AND tr.CourseCode = N'TESTAUD01'
              AND tr.RequestStatus IN (N'Pending', N'Completed')
          )
    ORDER BY e.BusinessEntityID;

    IF @EmpID IS NULL
        PRINT 'TEST RESULT: SKIP — no free employee available.';
    ELSE
    BEGIN
        INSERT INTO HRTrainingOps.TrainingRequests
            (BusinessEmployeeID, CourseCode, EnrollmentDate, RequestStatus)
        VALUES
            (@EmpID, N'TESTAUD01', CAST(SYSDATETIME() AS DATE), N'Pending');

        SET @ReqID = SCOPE_IDENTITY();

        SELECT @AuditBefore = COUNT(*)
        FROM HRTrainingOps.ErrorLog
        WHERE LogCategory = N'Audit'
          AND ErrorProcedure = N'trg_TrainingRequests_AuditStatusChange';

        UPDATE HRTrainingOps.TrainingRequests
        SET RequestStatus = N'Failed'
        WHERE TrainingRequestID = @ReqID;

        SELECT @AuditAfter = COUNT(*)
        FROM HRTrainingOps.ErrorLog
        WHERE LogCategory = N'Audit'
          AND ErrorProcedure = N'trg_TrainingRequests_AuditStatusChange';

        IF @AuditAfter > @AuditBefore
            PRINT 'TEST RESULT: PASS — status change was audited.';
        ELSE
            PRINT 'TEST RESULT: FAIL — no audit row was written.';

        DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = @ReqID;
    END
END TRY
BEGIN CATCH
    PRINT 'TEST RESULT: FAIL — ' + ERROR_MESSAGE();
END CATCH;
GO
