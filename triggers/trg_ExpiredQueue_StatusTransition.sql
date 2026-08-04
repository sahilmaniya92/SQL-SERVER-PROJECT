/*
    HRTrainingOps - Phase II
    Script : trg_ExpiredQueue_StatusTransition.sql
    Purpose: AFTER UPDATE — enforce QueueStatus path:
             Pending Review -> Notified -> Resolved
    Owner  : Parth Patel (Logic Developer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.trg_ExpiredQueue_StatusTransition', N'TR') IS NOT NULL
    DROP TRIGGER HRTrainingOps.trg_ExpiredQueue_StatusTransition;
GO

CREATE TRIGGER HRTrainingOps.trg_ExpiredQueue_StatusTransition
ON HRTrainingOps.ExpiredCertificationQueue
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(QueueStatus)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted AS i
            INNER JOIN deleted AS d
                ON d.QueueID = i.QueueID
            WHERE NOT (
                    (d.QueueStatus = N'Pending Review' AND i.QueueStatus IN (N'Pending Review', N'Notified'))
                 OR (d.QueueStatus = N'Notified'       AND i.QueueStatus IN (N'Notified', N'Resolved'))
                 OR (d.QueueStatus = N'Resolved'       AND i.QueueStatus = N'Resolved')
                 OR (d.QueueStatus = i.QueueStatus)
            )
        )
        BEGIN
            INSERT INTO HRTrainingOps.ErrorLog
                (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
            VALUES
                (50010,
                 N'Invalid QueueStatus transition. Allowed: Pending Review -> Notified -> Resolved.',
                 N'trg_ExpiredQueue_StatusTransition',
                 NULL,
                 N'Error');

            THROW 50010,
                  'Invalid QueueStatus transition. Allowed: Pending Review -> Notified -> Resolved.',
                  1;
        END;
    END;
END;
GO

PRINT 'Trigger HRTrainingOps.trg_ExpiredQueue_StatusTransition created.';
GO

/* ========== TEST CASE ========== */
PRINT '--- TEST: trg_ExpiredQueue_StatusTransition (rejects invalid jump) ---';
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'TESTQ01')
        INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
        VALUES (N'TESTQ01', N'Queue Transition Test Course', 12, 0);

    DECLARE @EmpID INT;
    DECLARE @ReqID INT;
    DECLARE @QueueID INT;

    SELECT TOP (1) @EmpID = e.BusinessEntityID
    FROM HumanResources.Employee AS e
    WHERE e.CurrentFlag = 1
      AND NOT EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests AS tr
            WHERE tr.BusinessEmployeeID = e.BusinessEntityID
              AND tr.CourseCode = N'TESTQ01'
              AND tr.RequestStatus IN (N'Pending', N'Completed')
          )
    ORDER BY e.BusinessEntityID;

    IF @EmpID IS NULL
        PRINT 'TEST RESULT: SKIP — no free employee available.';
    ELSE
    BEGIN
        INSERT INTO HRTrainingOps.TrainingRequests
            (BusinessEmployeeID, CourseCode, EnrollmentDate, ExamDate, Score,
             CertificationExpiryDate, RequestStatus)
        VALUES
            (@EmpID, N'TESTQ01', '2024-01-01', '2024-01-15', 80.00, '2024-06-01', N'Expired');

        SET @ReqID = SCOPE_IDENTITY();

        INSERT INTO HRTrainingOps.ExpiredCertificationQueue
            (TrainingRequestID, BusinessEmployeeID, CourseCode, ExpiryDate, DaysOverdue, QueueStatus)
        VALUES
            (@ReqID, @EmpID, N'TESTQ01', '2024-06-01', 30, N'Pending Review');

        SET @QueueID = SCOPE_IDENTITY();

        BEGIN TRY
            /* Invalid: Pending Review -> Resolved (must go through Notified) */
            UPDATE HRTrainingOps.ExpiredCertificationQueue
            SET QueueStatus = N'Resolved'
            WHERE QueueID = @QueueID;

            PRINT 'TEST RESULT: FAIL — invalid transition was accepted.';
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 50010
                PRINT 'TEST RESULT: PASS — invalid queue transition blocked.';
            ELSE
                PRINT 'TEST RESULT: FAIL — unexpected error: ' + ERROR_MESSAGE();
        END CATCH;

        DELETE FROM HRTrainingOps.ExpiredCertificationQueue WHERE QueueID = @QueueID;
        DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = @ReqID;
    END
END TRY
BEGIN CATCH
    PRINT 'TEST RESULT: FAIL — ' + ERROR_MESSAGE();
END CATCH;
GO
