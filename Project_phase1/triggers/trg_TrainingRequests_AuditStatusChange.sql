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
