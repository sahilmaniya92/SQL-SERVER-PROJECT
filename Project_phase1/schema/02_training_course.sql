/*
    HRTrainingOps - Phase I
    Script : 02_training_course.sql
    Purpose: Training course catalog (3NF entity)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.TrainingCourse', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.TrainingCourse
    (
        CourseCode      NVARCHAR(10)  NOT NULL,
        CourseName      NVARCHAR(100) NOT NULL,
        ValidityMonths  INT           NOT NULL,
        IsMandatory     BIT           NOT NULL
            CONSTRAINT DF_TrainingCourse_IsMandatory DEFAULT (0),
        CreatedDate     DATETIME2(0)  NOT NULL
            CONSTRAINT DF_TrainingCourse_CreatedDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_TrainingCourse
            PRIMARY KEY CLUSTERED (CourseCode),

        CONSTRAINT CK_TrainingCourse_ValidityMonths
            CHECK (ValidityMonths > 0),

        CONSTRAINT CK_TrainingCourse_CourseCode_NotEmpty
            CHECK (LEN(LTRIM(RTRIM(CourseCode))) > 0),

        CONSTRAINT CK_TrainingCourse_CourseName_NotEmpty
            CHECK (LEN(LTRIM(RTRIM(CourseName))) > 0)
    );

    PRINT 'Table HRTrainingOps.TrainingCourse created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.TrainingCourse already exists.';
END
GO
