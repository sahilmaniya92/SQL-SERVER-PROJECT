/*
    HRTrainingOps - Phase I
    Script : 03_training_requests.sql
    Purpose: Employee training enrollment and certification records
    Depends: 02_training_course.sql
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.TrainingRequests', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.TrainingRequests
    (
        TrainingRequestID       INT IDENTITY(1, 1) NOT NULL,
        BusinessEmployeeID      INT                NOT NULL,
        CourseCode              NVARCHAR(10)       NOT NULL,
        EnrollmentDate          DATE               NOT NULL,
        ExamDate                DATE               NULL,
        Score                   DECIMAL(5, 2)      NULL,
        CertificationExpiryDate DATE               NULL,
        RequestStatus           NVARCHAR(20)       NOT NULL
            CONSTRAINT DF_TrainingRequests_RequestStatus DEFAULT (N'Pending'),
        DepartmentID            SMALLINT           NULL,
        CreatedDate             DATETIME2(0)       NOT NULL
            CONSTRAINT DF_TrainingRequests_CreatedDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_TrainingRequests
            PRIMARY KEY CLUSTERED (TrainingRequestID),

        CONSTRAINT FK_TrainingRequests_TrainingCourse
            FOREIGN KEY (CourseCode)
            REFERENCES HRTrainingOps.TrainingCourse (CourseCode),

        CONSTRAINT FK_TrainingRequests_Employee
            FOREIGN KEY (BusinessEmployeeID)
            REFERENCES HumanResources.Employee (BusinessEntityID),

        CONSTRAINT FK_TrainingRequests_Department
            FOREIGN KEY (DepartmentID)
            REFERENCES HumanResources.Department (DepartmentID),

        CONSTRAINT CK_TrainingRequests_Score_Range
            CHECK (Score IS NULL OR (Score >= 0 AND Score <= 100)),

        CONSTRAINT CK_TrainingRequests_RequestStatus
            CHECK (RequestStatus IN (N'Pending', N'Completed', N'Failed', N'Expired')),

        CONSTRAINT CK_TrainingRequests_ExamAfterEnrollment
            CHECK (ExamDate IS NULL OR ExamDate >= EnrollmentDate),

        CONSTRAINT CK_TrainingRequests_ExpiryAfterExam
            CHECK (
                CertificationExpiryDate IS NULL
                OR ExamDate IS NULL
                OR CertificationExpiryDate >= ExamDate
            )
    );

    CREATE UNIQUE NONCLUSTERED INDEX UX_TrainingRequests_ActiveEnrollment
        ON HRTrainingOps.TrainingRequests (BusinessEmployeeID, CourseCode)
        WHERE RequestStatus IN (N'Pending', N'Completed');

    PRINT 'Table HRTrainingOps.TrainingRequests created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.TrainingRequests already exists.';
END
GO
