/*
    HRTrainingOps - Phase II
    Script : expired_certification_review_cursor.sql
    Purpose: STATIC cursor — process Pending Review queue items and mark Notified
             (row-by-row notification generation for Workflow 2 demonstration)
    Owner  : Dhruv (Security & Optimization Lead)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_ProcessExpiryQueueWithCursor', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_ProcessExpiryQueueWithCursor;
GO

CREATE PROCEDURE HRTrainingOps.usp_ProcessExpiryQueueWithCursor
    @ProcessedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @QueueID INT;
    DECLARE @BusinessEmployeeID INT;
    DECLARE @CourseCode NVARCHAR(10);
    DECLARE @ExpiryDate DATE;
    DECLARE @DaysOverdue INT;

    SET @ProcessedCount = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE expiry_cursor CURSOR STATIC LOCAL FOR
            SELECT
                q.QueueID,
                q.BusinessEmployeeID,
                q.CourseCode,
                q.ExpiryDate,
                q.DaysOverdue
            FROM HRTrainingOps.ExpiredCertificationQueue AS q
            WHERE q.QueueStatus = N'Pending Review'
            ORDER BY q.DaysOverdue DESC, q.QueueID;

        OPEN expiry_cursor;

        FETCH NEXT FROM expiry_cursor
            INTO @QueueID, @BusinessEmployeeID, @CourseCode, @ExpiryDate, @DaysOverdue;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO HRTrainingOps.NotificationLog
                (BusinessEmployeeID, NotificationType, MessageText)
            VALUES
                (@BusinessEmployeeID,
                 N'Expiry Warning',
                 N'Certification for ' + @CourseCode
                 + N' expired on ' + CONVERT(NVARCHAR(10), @ExpiryDate, 120)
                 + N' (' + CAST(@DaysOverdue AS NVARCHAR(10)) + N' days overdue). QueueID='
                 + CAST(@QueueID AS NVARCHAR(20)));

            UPDATE HRTrainingOps.ExpiredCertificationQueue
            SET QueueStatus = N'Notified'
            WHERE QueueID = @QueueID
              AND QueueStatus = N'Pending Review';

            SET @ProcessedCount += 1;

            FETCH NEXT FROM expiry_cursor
                INTO @QueueID, @BusinessEmployeeID, @CourseCode, @ExpiryDate, @DaysOverdue;
        END;

        CLOSE expiry_cursor;
        DEALLOCATE expiry_cursor;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(N'local', N'expiry_cursor') >= 0
            CLOSE expiry_cursor;
        IF CURSOR_STATUS(N'local', N'expiry_cursor') >= -1
            DEALLOCATE expiry_cursor;

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

PRINT 'Procedure HRTrainingOps.usp_ProcessExpiryQueueWithCursor created (static cursor).';
GO
