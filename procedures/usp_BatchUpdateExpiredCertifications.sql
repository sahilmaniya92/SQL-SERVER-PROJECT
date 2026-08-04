/*
    HRTrainingOps - Phase II
    Script : usp_BatchUpdateExpiredCertifications.sql
    Purpose: Batch-populate ExpiredCertificationQueue for expired certifications
    Owner  : Dhruv (Security & Optimization Lead)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_BatchUpdateExpiredCertifications', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_BatchUpdateExpiredCertifications;
GO

CREATE PROCEDURE HRTrainingOps.usp_BatchUpdateExpiredCertifications
    @AsOfDate DATE = NULL,
    @RowsQueued INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @Cutoff DATE = ISNULL(@AsOfDate, CAST(SYSDATETIME() AS DATE));
    SET @RowsQueued = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Mark completed certifications past expiry as Expired */
        UPDATE HRTrainingOps.TrainingRequests
        SET RequestStatus = N'Expired'
        WHERE RequestStatus = N'Completed'
          AND CertificationExpiryDate IS NOT NULL
          AND CertificationExpiryDate < @Cutoff;

        INSERT INTO HRTrainingOps.ExpiredCertificationQueue
            (TrainingRequestID, BusinessEmployeeID, CourseCode, ExpiryDate, DaysOverdue, QueueStatus)
        SELECT
            tr.TrainingRequestID,
            tr.BusinessEmployeeID,
            tr.CourseCode,
            tr.CertificationExpiryDate,
            DATEDIFF(DAY, tr.CertificationExpiryDate, @Cutoff),
            N'Pending Review'
        FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.CertificationExpiryDate IS NOT NULL
          AND tr.CertificationExpiryDate < @Cutoff
          AND tr.RequestStatus IN (N'Expired', N'Completed', N'Failed')
          AND NOT EXISTS (
                SELECT 1
                FROM HRTrainingOps.ExpiredCertificationQueue AS q
                WHERE q.TrainingRequestID = tr.TrainingRequestID
              );

        SET @RowsQueued = @@ROWCOUNT;

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

PRINT 'Procedure HRTrainingOps.usp_BatchUpdateExpiredCertifications created.';
GO

/* ========== TEST CASE ========== */
PRINT '--- TEST: usp_BatchUpdateExpiredCertifications ---';
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'TESTBAT01')
        INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
        VALUES (N'TESTBAT01', N'Batch Expiry Test Course', 12, 0);

    DECLARE @EmpID INT;
    DECLARE @ReqID INT;
    DECLARE @RowsQueued INT;
    DECLARE @QueueID INT;

    SELECT TOP (1) @EmpID = e.BusinessEntityID
    FROM HumanResources.Employee AS e
    WHERE e.CurrentFlag = 1
      AND NOT EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests AS tr
            WHERE tr.BusinessEmployeeID = e.BusinessEntityID
              AND tr.CourseCode = N'TESTBAT01'
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
            (@EmpID, N'TESTBAT01', '2023-01-01', '2023-01-15', 90.00, '2023-06-01', N'Completed');

        SET @ReqID = SCOPE_IDENTITY();

        EXEC HRTrainingOps.usp_BatchUpdateExpiredCertifications
            @AsOfDate = NULL,
            @RowsQueued = @RowsQueued OUTPUT;

        SELECT @QueueID = QueueID
        FROM HRTrainingOps.ExpiredCertificationQueue
        WHERE TrainingRequestID = @ReqID;

        IF @QueueID IS NOT NULL
            PRINT 'TEST RESULT: PASS — queued TrainingRequestID=' + CAST(@ReqID AS NVARCHAR(20))
                 + N', RowsQueued=' + CAST(@RowsQueued AS NVARCHAR(20));
        ELSE
            PRINT 'TEST RESULT: FAIL — expired request was not queued.';

        IF @QueueID IS NOT NULL
            DELETE FROM HRTrainingOps.ExpiredCertificationQueue WHERE QueueID = @QueueID;
        DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = @ReqID;
    END
END TRY
BEGIN CATCH
    PRINT 'TEST RESULT: FAIL — ' + ERROR_MESSAGE();
END CATCH;
GO
