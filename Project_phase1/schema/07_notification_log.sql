/*
    HRTrainingOps - Phase I
    Script : 07_notification_log.sql
    Purpose: Notification messages for training events
    Depends: 01_create_schema.sql
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.NotificationLog', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.NotificationLog
    (
        NotificationID      INT IDENTITY(1, 1) NOT NULL,
        BusinessEmployeeID  INT                NOT NULL,
        NotificationType    NVARCHAR(50)       NOT NULL,
        MessageText         NVARCHAR(500)      NOT NULL,
        SentDate            DATETIME2(0)       NOT NULL
            CONSTRAINT DF_NotificationLog_SentDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_NotificationLog
            PRIMARY KEY CLUSTERED (NotificationID),

        CONSTRAINT FK_NotificationLog_Employee
            FOREIGN KEY (BusinessEmployeeID)
            REFERENCES HumanResources.Employee (BusinessEntityID),

        CONSTRAINT CK_NotificationLog_Type
            CHECK (NotificationType IN (
                N'Expiry Warning',
                N'Failed Exam',
                N'Re-Enroll',
                N'Enrollment Confirmation'
            )),

        CONSTRAINT CK_NotificationLog_MessageText_NotEmpty
            CHECK (LEN(LTRIM(RTRIM(MessageText))) > 0)
    );

    PRINT 'Table HRTrainingOps.NotificationLog created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.NotificationLog already exists.';
END
GO
