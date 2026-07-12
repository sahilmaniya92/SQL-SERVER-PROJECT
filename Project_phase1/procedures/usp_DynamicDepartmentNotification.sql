/*
    HRTrainingOps - Phase II
    Script : usp_DynamicDepartmentNotification.sql
    Purpose: DYNAMIC cursor — iterate departments and generate compliance notifications
             Uses CURSOR DYNAMIC (sees underlying data changes while iterating).
             Optional @DepartmentName filter demonstrates parameterized department scope.
    Owner  : Dhruv (Security & Optimization Lead)
    Workflow 3
*/
USE AdventureWorks2022;
GO

IF OBJECT_ID(N'HRTrainingOps.usp_DynamicDepartmentNotification', N'P') IS NOT NULL
    DROP PROCEDURE HRTrainingOps.usp_DynamicDepartmentNotification;
GO

CREATE PROCEDURE HRTrainingOps.usp_DynamicDepartmentNotification
    @DepartmentName NVARCHAR(50) = NULL,
    @NotificationsCreated INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @DepartmentID SMALLINT;
    DECLARE @DeptName NVARCHAR(50);
    DECLARE @MissingCount INT;
    DECLARE @SampleEmployeeID INT;

    SET @NotificationsCreated = 0;

    BEGIN TRY
        /*
            Stage the department compliance gaps in a temp table, then walk them
            with a DYNAMIC cursor (SQL Server cursor type = DYNAMIC).
        */
        IF OBJECT_ID(N'tempdb..#DeptGaps') IS NOT NULL
            DROP TABLE #DeptGaps;

        CREATE TABLE #DeptGaps
        (
            DepartmentID     SMALLINT NOT NULL,
            DepartmentName   NVARCHAR(50) NOT NULL,
            MissingCount     INT NOT NULL,
            SampleEmployeeID INT NOT NULL
        );

        INSERT INTO #DeptGaps (DepartmentID, DepartmentName, MissingCount, SampleEmployeeID)
        SELECT
            d.DepartmentID,
            d.Name,
            COUNT(*),
            MIN(edh.BusinessEntityID)
        FROM HumanResources.Department AS d
        INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
            ON edh.DepartmentID = d.DepartmentID
           AND edh.EndDate IS NULL
        INNER JOIN HumanResources.Employee AS e
            ON e.BusinessEntityID = edh.BusinessEntityID
           AND e.CurrentFlag = 1
        INNER JOIN HRTrainingOps.DepartmentTrainingRequirement AS req
            ON req.DepartmentID = d.DepartmentID
           AND req.IsRequired = 1
        WHERE (@DepartmentName IS NULL OR d.Name = @DepartmentName)
          AND NOT EXISTS (
                SELECT 1
                FROM HRTrainingOps.TrainingRequests AS tr
                WHERE tr.BusinessEmployeeID = edh.BusinessEntityID
                  AND tr.CourseCode = req.CourseCode
                  AND tr.RequestStatus IN (N'Pending', N'Completed')
              )
        GROUP BY d.DepartmentID, d.Name
        HAVING COUNT(*) > 0;

        BEGIN TRANSACTION;

        DECLARE dept_cursor CURSOR DYNAMIC LOCAL FOR
            SELECT DepartmentID, DepartmentName, MissingCount, SampleEmployeeID
            FROM #DeptGaps
            ORDER BY DepartmentName;

        OPEN dept_cursor;

        FETCH NEXT FROM dept_cursor
            INTO @DepartmentID, @DeptName, @MissingCount, @SampleEmployeeID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO HRTrainingOps.NotificationLog
                (BusinessEmployeeID, NotificationType, MessageText)
            VALUES
                (@SampleEmployeeID,
                 N'Expiry Warning',
                 N'Department [' + @DeptName + N'] has '
                 + CAST(@MissingCount AS NVARCHAR(10))
                 + N' missing required training enrollment(s). Please review compliance.');

            SET @NotificationsCreated += 1;

            FETCH NEXT FROM dept_cursor
                INTO @DepartmentID, @DeptName, @MissingCount, @SampleEmployeeID;
        END;

        CLOSE dept_cursor;
        DEALLOCATE dept_cursor;

        COMMIT TRANSACTION;

        DROP TABLE #DeptGaps;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(N'local', N'dept_cursor') >= 0
            CLOSE dept_cursor;
        IF CURSOR_STATUS(N'local', N'dept_cursor') >= -1
            DEALLOCATE dept_cursor;

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID(N'tempdb..#DeptGaps') IS NOT NULL
            DROP TABLE #DeptGaps;

        INSERT INTO HRTrainingOps.ErrorLog
            (ErrorNumber, ErrorMessage, ErrorProcedure, ErrorLine, LogCategory)
        VALUES
            (ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_PROCEDURE(), ERROR_LINE(), N'Error');

        THROW;
    END CATCH;
END;
GO

PRINT 'Procedure HRTrainingOps.usp_DynamicDepartmentNotification created (dynamic cursor).';
GO
