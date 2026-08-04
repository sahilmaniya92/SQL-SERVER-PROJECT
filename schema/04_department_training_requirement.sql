/*
    HRTrainingOps - Phase I
    Script : 04_department_training_requirement.sql
    Purpose: Required training courses per department
    Depends: 02_training_course.sql
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.DepartmentTrainingRequirement', N'U') IS NULL
BEGIN
    CREATE TABLE HRTrainingOps.DepartmentTrainingRequirement
    (
        RequirementID   INT IDENTITY(1, 1) NOT NULL,
        DepartmentID    SMALLINT           NOT NULL,
        CourseCode      NVARCHAR(10)       NOT NULL,
        IsRequired      BIT                NOT NULL
            CONSTRAINT DF_DepartmentTrainingRequirement_IsRequired DEFAULT (1),
        CreatedDate     DATETIME2(0)       NOT NULL
            CONSTRAINT DF_DepartmentTrainingRequirement_CreatedDate DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_DepartmentTrainingRequirement
            PRIMARY KEY CLUSTERED (RequirementID),

        CONSTRAINT UQ_DepartmentTrainingRequirement_DeptCourse
            UNIQUE (DepartmentID, CourseCode),

        CONSTRAINT FK_DepartmentTrainingRequirement_Department
            FOREIGN KEY (DepartmentID)
            REFERENCES HumanResources.Department (DepartmentID),

        CONSTRAINT FK_DepartmentTrainingRequirement_TrainingCourse
            FOREIGN KEY (CourseCode)
            REFERENCES HRTrainingOps.TrainingCourse (CourseCode)
    );

    PRINT 'Table HRTrainingOps.DepartmentTrainingRequirement created.';
END
ELSE
BEGIN
    PRINT 'Table HRTrainingOps.DepartmentTrainingRequirement already exists.';
END
GO
