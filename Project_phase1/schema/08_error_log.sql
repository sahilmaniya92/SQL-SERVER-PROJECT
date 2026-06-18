/*
    HRTrainingOps - Phase I
    Script : 08_error_log.sql
    Purpose: Central error and audit log
    Depends: 01_create_schema.sql
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.ErrorLog', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.ErrorLog
    (
        ErrorLogID      INT IDENTITY(1, 1) NOT NULL,
        ErrorNumber     INT                NULL,
        ErrorMessage    NVARCHAR(4000)     NULL,
        ErrorProcedure  NVARCHAR(200)      NULL,
        ErrorLine       INT                NULL,
        LogCategory     NVARCHAR(30)       NOT NULL
            CONSTRAINT DF_ErrorLog_LogCategory DEFAULT (N'Error'),
        LoggedDate      DATETIME2(0)       NOT NULL
            CONSTRAINT DF_ErrorLog_LoggedDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_ErrorLog
            PRIMARY KEY CLUSTERED (ErrorLogID),

        CONSTRAINT CK_ErrorLog_LogCategory
            CHECK (LogCategory IN (N'Error', N'Audit', N'Warning'))
    );

    PRINT 'Table HRTrainingOps.ErrorLog created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.ErrorLog already exists.';
END
GO
