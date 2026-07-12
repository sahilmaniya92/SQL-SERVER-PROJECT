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
