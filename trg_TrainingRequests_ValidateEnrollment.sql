/*
    HRTrainingOps - Phase II
    Script : trg_TrainingRequests_ValidateEnrollment.sql
    Purpose: AFTER INSERT, UPDATE — validate enrollment date, exam/score rules,
             and block future EnrollmentDate values
    Owner  : Parth Patel (Logic Developer)
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.trg_TrainingRequests_ValidateEnrollment', N'TR') IS NOT NULL
    DROP TRIGGER HRTrainingOps.trg_TrainingRequests_ValidateEnrollment;
GO

CREATE TRIGGER HRTrainingOps.trg_TrainingRequests_ValidateEnrollment
ON HRTrainingOps.TrainingRequests
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.EnrollmentDate > CAST(SYSDATETIME() AS DATE)
    )
    BEGIN
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (50001, N'EnrollmentDate cannot be in the future.',
             N'trg_TrainingRequests_ValidateEnrollment', NULL, N'Error');

        THROW 50001, 'EnrollmentDate cannot be in the future.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.ExamDate IS NOT NULL
          AND i.ExamDate < i.EnrollmentDate
    )
    BEGIN
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (50002, N'ExamDate cannot be earlier than EnrollmentDate.',
             N'trg_TrainingRequests_ValidateEnrollment', NULL, N'Error');

        THROW 50002, 'ExamDate cannot be earlier than EnrollmentDate.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.Score IS NOT NULL
          AND (i.Score < 0 OR i.Score > 100)
    )
    BEGIN
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (50003, N'Score must be between 0 and 100.',
             N'trg_TrainingRequests_ValidateEnrollment', NULL, N'Error');

        THROW 50003, 'Score must be between 0 and 100.', 1;
    END;

    /* Duplicate active enrollment (Pending/Completed) for same employee + course */
    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN HRTrainingOps.TrainingRequests AS tr
            ON tr.BusinessEmployeeID = i.BusinessEmployeeID
           AND tr.CourseCode = i.CourseCode
           AND tr.TrainingRequestID <> i.TrainingRequestID
           AND tr.RequestStatus IN (N'Pending', N'Completed')
           AND i.RequestStatus IN (N'Pending', N'Completed')
    )
    BEGIN
        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (50004, N'Duplicate active enrollment for employee and course is not allowed.',
             N'trg_TrainingRequests_ValidateEnrollment', NULL, N'Error');

        THROW 50004, 'Duplicate active enrollment for employee and course is not allowed.', 1;
    END;
END;
GO

PRINT 'Trigger HRTrainingOps.trg_TrainingRequests_ValidateEnrollment created.';
GO

/* ========== TEST CASE ========== */
PRINT '--- TEST: trg_TrainingRequests_ValidateEnrollment (rejects future EnrollmentDate) ---';
BEGIN TRY
    IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'TESTVAL01')
        INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
        VALUES (N'TESTVAL01', N'Trigger Validate Test Course', 12, 0);

    DECLARE @EmpID INT;
    SELECT TOP (1) @EmpID = BusinessEntityID
    FROM HumanResources.Employee
    WHERE CurrentFlag = 1
    ORDER BY BusinessEntityID;

    IF @EmpID IS NULL
        PRINT 'TEST RESULT: SKIP — no active employee found.';
    ELSE
    BEGIN
        BEGIN TRY
            INSERT INTO HRTrainingOps.TrainingRequests
                (BusinessEmployeeID, CourseCode, EnrollmentDate, RequestStatus)
            VALUES
                (@EmpID, N'TESTVAL01', DATEADD(DAY, 7, CAST(SYSDATETIME() AS DATE)), N'Pending');

            PRINT 'TEST RESULT: FAIL — future EnrollmentDate was accepted.';
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() = 50001
                PRINT 'TEST RESULT: PASS — trigger blocked future EnrollmentDate.';
            ELSE
                PRINT 'TEST RESULT: FAIL — unexpected error: ' + ERROR_MESSAGE();
        END CATCH;
    END
END TRY
BEGIN CATCH
    PRINT 'TEST RESULT: FAIL — ' + ERROR_MESSAGE();
END CATCH;
GO
