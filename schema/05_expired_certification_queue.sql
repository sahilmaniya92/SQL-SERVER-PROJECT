/*
    HRTrainingOps - Phase I
    Script : 05_expired_certification_queue.sql
    Purpose: Queue for expired or soon-to-expire certifications
    Depends: 03_training_requests.sql
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.ExpiredCertificationQueue', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.ExpiredCertificationQueue
    (
        QueueID             INT IDENTITY(1, 1) NOT NULL,
        TrainingRequestID   INT                NOT NULL,
        BusinessEmployeeID  INT                NOT NULL,
        CourseCode          NVARCHAR(10)       NOT NULL,
        ExpiryDate          DATE               NOT NULL,
        DaysOverdue         INT                NOT NULL,
        QueueStatus         NVARCHAR(20)       NOT NULL
            CONSTRAINT DF_ExpiredCertificationQueue_QueueStatus DEFAULT (N'Pending Review'),
        QueuedDate          DATETIME2(0)       NOT NULL
            CONSTRAINT DF_ExpiredCertificationQueue_QueuedDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_ExpiredCertificationQueue
            PRIMARY KEY CLUSTERED (QueueID),

        CONSTRAINT FK_ExpiredCertificationQueue_TrainingRequests
            FOREIGN KEY (TrainingRequestID)
            REFERENCES HRTrainingOps.TrainingRequests (TrainingRequestID),

        CONSTRAINT FK_ExpiredCertificationQueue_Employee
            FOREIGN KEY (BusinessEmployeeID)
            REFERENCES HumanResources.Employee (BusinessEntityID),

        CONSTRAINT FK_ExpiredCertificationQueue_TrainingCourse
            FOREIGN KEY (CourseCode)
            REFERENCES HRTrainingOps.TrainingCourse (CourseCode),

        CONSTRAINT CK_ExpiredCertificationQueue_QueueStatus
            CHECK (QueueStatus IN (N'Pending Review', N'Notified', N'Resolved')),

        CONSTRAINT UQ_ExpiredCertificationQueue_Request
            UNIQUE (TrainingRequestID)
    );

    PRINT 'Table HRTrainingOps.ExpiredCertificationQueue created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.ExpiredCertificationQueue already exists.';
END
GO
