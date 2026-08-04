/*
    HRTrainingOps - Phase II
    Script : usp_ProcessCertificationReview.sql
    Purpose: Manager approval workflow — Re-Enroll / Waived / Terminated
             Multi-table transaction updating queue, review, and request rows
    Owner  : Parth Patel (Logic Developer)
    Workflow 2
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_ProcessCertificationReview', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_ProcessCertificationReview;
GO

CREATE PROCEDURE HRTrainingOps.usp_ProcessCertificationReview
    @QueueID        INT,
    @ReviewDecision NVARCHAR(30),
    @ReviewNotes    NVARCHAR(500) = NULL,
    @ReviewedBy     NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @TrainingRequestID INT;
    DECLARE @BusinessEmployeeID INT;
    DECLARE @CourseCode NVARCHAR(10);
    DECLARE @QueueStatus NVARCHAR(20);

    BEGIN TRY
        IF @QueueID IS NULL OR @ReviewDecision IS NULL OR @ReviewedBy IS NULL
            THROW 51201, 'QueueID, ReviewDecision, and ReviewedBy are required.', 1;

        IF @ReviewDecision NOT IN (N'Re-Enroll', N'Waived', N'Terminated')
            THROW 51202, 'ReviewDecision must be Re-Enroll, Waived, or Terminated.', 1;

        IF LEN(LTRIM(RTRIM(@ReviewedBy))) = 0
            THROW 51203, 'ReviewedBy cannot be empty.', 1;

        SELECT
            @TrainingRequestID = q.TrainingRequestID,
            @BusinessEmployeeID = q.BusinessEmployeeID,
            @CourseCode = q.CourseCode,
            @QueueStatus = q.QueueStatus
        FROM HRTrainingOps.ExpiredCertificationQueue AS q
        WHERE q.QueueID = @QueueID;

        IF @TrainingRequestID IS NULL
            THROW 51204, 'QueueID not found.', 1;

        IF @QueueStatus = N'Resolved'
            THROW 51205, 'Queue item is already Resolved.', 1;

        BEGIN TRANSACTION;

        /* Advance Pending Review -> Notified if needed (status transition trigger) */
        IF @QueueStatus = N'Pending Review'
        BEGIN
            UPDATE HRTrainingOps.ExpiredCertificationQueue
            SET QueueStatus = N'Notified'
            WHERE QueueID = @QueueID;

            SET @QueueStatus = N'Notified';
        END;

        INSERT INTO HRTrainingOps.CertificationReleaseReview
            (TrainingRequestID, ReviewDecision, ReviewNotes, ReviewedBy)
        VALUES
            (@TrainingRequestID, @ReviewDecision, @ReviewNotes, @ReviewedBy);

        IF @ReviewDecision = N'Re-Enroll'
        BEGIN
            UPDATE HRTrainingOps.TrainingRequests
            SET RequestStatus = N'Expired'
            WHERE TrainingRequestID = @TrainingRequestID;

            INSERT INTO HRTrainingOps.NotificationLog
                (BusinessEmployeeID, NotificationType, MessageText)
            VALUES
                (@BusinessEmployeeID,
                 N'Re-Enroll',
                 N'Re-enrollment required for course ' + @CourseCode
                 + N'. QueueID=' + CAST(@QueueID AS NVARCHAR(20)));
        END;
        ELSE IF @ReviewDecision = N'Waived'
        BEGIN
            UPDATE HRTrainingOps.TrainingRequests
            SET RequestStatus = N'Completed'
            WHERE TrainingRequestID = @TrainingRequestID;

            INSERT INTO HRTrainingOps.NotificationLog
                (BusinessEmployeeID, NotificationType, MessageText)
            VALUES
                (@BusinessEmployeeID,
                 N'Expiry Warning',
                 N'Certification requirement waived for course ' + @CourseCode
                 + N'. QueueID=' + CAST(@QueueID AS NVARCHAR(20)));
        END;
        ELSE /* Terminated */
        BEGIN
            UPDATE HRTrainingOps.TrainingRequests
            SET RequestStatus = N'Failed'
            WHERE TrainingRequestID = @TrainingRequestID;

            INSERT INTO HRTrainingOps.NotificationLog
                (BusinessEmployeeID, NotificationType, MessageText)
            VALUES
                (@BusinessEmployeeID,
                 N'Failed Exam',
                 N'Certification marked Terminated for course ' + @CourseCode
                 + N'. QueueID=' + CAST(@QueueID AS NVARCHAR(20)));
        END;

        UPDATE HRTrainingOps.ExpiredCertificationQueue
        SET QueueStatus = N'Resolved'
        WHERE QueueID = @QueueID;

        /* Audit entry for the review decision */
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (NULL,
             N'Review completed for QueueID=' + CAST(@QueueID AS NVARCHAR(20))
             + N' Decision=' + @ReviewDecision + N' by ' + @ReviewedBy,
             N'usp_ProcessCertificationReview',
             NULL,
             N'Audit');

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

PRINT 'Procedure HRTrainingOps.usp_ProcessCertificationReview created.';
GO

/* ========== TEST CASE ========== */
PRINT '--- TEST: usp_ProcessCertificationReview ---';
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'TESTREV01')
        INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
        VALUES (N'TESTREV01', N'Review Proc Test Course', 12, 0);

    DECLARE @EmpID INT;
    DECLARE @ReqID INT;
    DECLARE @QueueID INT;
    DECLARE @ReviewID INT;

    SELECT TOP (1) @EmpID = e.BusinessEntityID
    FROM HumanResources.Employee AS e
    WHERE e.CurrentFlag = 1
      AND NOT EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests AS tr
            WHERE tr.BusinessEmployeeID = e.BusinessEntityID
              AND tr.CourseCode = N'TESTREV01'
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
            (@EmpID, N'TESTREV01', '2023-01-01', '2023-01-15', 75.00, '2023-06-01', N'Expired');

        SET @ReqID = SCOPE_IDENTITY();

        INSERT INTO HRTrainingOps.ExpiredCertificationQueue
            (TrainingRequestID, BusinessEmployeeID, CourseCode, ExpiryDate, DaysOverdue, QueueStatus)
        VALUES
            (@ReqID, @EmpID, N'TESTREV01', '2023-06-01', 100, N'Pending Review');

        SET @QueueID = SCOPE_IDENTITY();

        EXEC HRTrainingOps.usp_ProcessCertificationReview
            @QueueID = @QueueID,
            @ReviewDecision = N'Waived',
            @ReviewNotes = N'Test case waiver',
            @ReviewedBy = N'TEST_SCRIPT';

        SELECT @ReviewID = ReviewID
        FROM HRTrainingOps.CertificationReleaseReview
        WHERE TrainingRequestID = @ReqID
          AND ReviewedBy = N'TEST_SCRIPT';

        IF @ReviewID IS NOT NULL
           AND EXISTS (
                SELECT 1 FROM HRTrainingOps.ExpiredCertificationQueue
                WHERE QueueID = @QueueID AND QueueStatus = N'Resolved'
           )
            PRINT 'TEST RESULT: PASS — review completed, QueueID resolved.';
        ELSE
            PRINT 'TEST RESULT: FAIL — review was not recorded/resolved.';

        DELETE FROM HRTrainingOps.CertificationReleaseReview WHERE ReviewID = @ReviewID;
        DELETE FROM HRTrainingOps.NotificationLog
        WHERE BusinessEmployeeID = @EmpID AND MessageText LIKE N'%TESTREV01%';
        DELETE FROM HRTrainingOps.ExpiredCertificationQueue WHERE QueueID = @QueueID;
        DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = @ReqID;
    END
END TRY
BEGIN CATCH
    PRINT 'TEST RESULT: FAIL — ' + ERROR_MESSAGE();
END CATCH;
GO
