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
