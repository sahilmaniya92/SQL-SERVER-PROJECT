/*
    HRTrainingOps - Phase III
    Script : test_data.sql
    Purpose: Full sample data load for demo, reporting, and index/IO tests
    Owner  : Sahil Maniya / Dhruv Patel (Integration)

    Prerequisites:
      - Phase I schema deployed
      - Phase II objects deployed (procedures preferred for enroll helper;
        this script also inserts directly where needed)
      - AdventureWorks2022 HumanResources employees present

    Safe to re-run: uses NOT EXISTS guards / natural keys.
*/
USE AdventureWorks2022;
GO

SET NOCOUNT ON;
PRINT '========== HRTrainingOps Phase III — test_data.sql ==========';
GO

/* =========================================================
   1) Course catalog
   ========================================================= */
PRINT '--- 1) TrainingCourse ---';

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'SAFETY01')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'SAFETY01', N'Workplace Safety Basics', 12, 1);

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'HRCOMP02')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'HRCOMP02', N'HR Compliance Essentials', 24, 1);

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'LEAD03')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'LEAD03', N'Leadership Fundamentals', 18, 0);

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'CYBER04')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'CYBER04', N'Cybersecurity Awareness', 12, 1);

IF NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingCourse WHERE CourseCode = N'FIRST05')
    INSERT INTO HRTrainingOps.TrainingCourse (CourseCode, CourseName, ValidityMonths, IsMandatory)
    VALUES (N'FIRST05', N'First Aid & CPR', 24, 0);
GO

/* =========================================================
   2) Department training requirements
      AdventureWorks: 1=Engineering, 3=Sales, 7=Production, 10=Finance, 16=Executive
   ========================================================= */
PRINT '--- 2) DepartmentTrainingRequirement ---';

DECLARE @Req TABLE (DepartmentID SMALLINT, CourseCode NVARCHAR(10));
INSERT INTO @Req (DepartmentID, CourseCode)
VALUES
    (7,  N'SAFETY01'),
    (7,  N'FIRST05'),
    (3,  N'HRCOMP02'),
    (3,  N'CYBER04'),
    (1,  N'CYBER04'),
    (10, N'HRCOMP02'),
    (16, N'LEAD03');

INSERT INTO HRTrainingOps.DepartmentTrainingRequirement (DepartmentID, CourseCode, IsRequired)
SELECT r.DepartmentID, r.CourseCode, 1
FROM @Req AS r
INNER JOIN HumanResources.Department AS d
    ON d.DepartmentID = r.DepartmentID
INNER JOIN HRTrainingOps.TrainingCourse AS c
    ON c.CourseCode = r.CourseCode
WHERE NOT EXISTS (
    SELECT 1
    FROM HRTrainingOps.DepartmentTrainingRequirement AS x
    WHERE x.DepartmentID = r.DepartmentID
      AND x.CourseCode = r.CourseCode
);
GO

/* =========================================================
   3) Training requests — mixed statuses across real employees
   ========================================================= */
PRINT '--- 3) TrainingRequests sample rows ---';
GO

/* Helper procedure: insert enrollment if no active duplicate */
IF OBJECT_ID(N'tempdb..#SeedEmployees') IS NOT NULL
    DROP TABLE #SeedEmployees;

CREATE TABLE #SeedEmployees
(
    BusinessEmployeeID INT NOT NULL,
    DepartmentID       SMALLINT NULL,
    CourseCode         NVARCHAR(10) NOT NULL,
    EnrollmentDate     DATE NOT NULL,
    ExamDate           DATE NULL,
    Score              DECIMAL(5, 2) NULL,
    ExpiryDate         DATE NULL,
    RequestStatus      NVARCHAR(20) NOT NULL
);

/* Pick active employees from known departments when available */
INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 7, N'SAFETY01', '2024-01-10', '2024-02-01', 88.00, '2024-06-01', N'Expired'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 7
WHERE e.CurrentFlag = 1
ORDER BY e.BusinessEntityID;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 7, N'FIRST05', '2025-03-01', NULL, NULL, NULL, N'Pending'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 7
WHERE e.CurrentFlag = 1
  AND e.BusinessEntityID NOT IN (SELECT BusinessEmployeeID FROM #SeedEmployees)
  AND NOT EXISTS (
        SELECT 1 FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'FIRST05'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 7, N'SAFETY01', '2025-01-15', '2025-02-01', 92.00, DATEADD(MONTH, 12, '2025-02-01'), N'Completed'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 7
WHERE e.CurrentFlag = 1
  AND NOT EXISTS (
        SELECT 1 FROM #SeedEmployees s
        WHERE s.BusinessEmployeeID = e.BusinessEntityID AND s.CourseCode = N'SAFETY01'
          AND s.RequestStatus IN (N'Pending', N'Completed')
  )
  AND NOT EXISTS (
        SELECT 1 FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'SAFETY01'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID DESC;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 3, N'HRCOMP02', '2024-06-01', '2024-06-20', 45.00, NULL, N'Failed'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 3
WHERE e.CurrentFlag = 1
ORDER BY e.BusinessEntityID;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 3, N'CYBER04', '2025-04-01', NULL, NULL, NULL, N'Pending'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 3
WHERE e.CurrentFlag = 1
  AND NOT EXISTS (
        SELECT 1 FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'CYBER04'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID DESC;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 1, N'CYBER04', '2024-03-01', '2024-03-15', 81.00, '2024-09-15', N'Expired'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 1
WHERE e.CurrentFlag = 1
ORDER BY e.BusinessEntityID;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 10, N'HRCOMP02', '2025-02-10', '2025-02-28', 76.00, DATEADD(MONTH, 24, '2025-02-28'), N'Completed'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 10
WHERE e.CurrentFlag = 1
  AND NOT EXISTS (
        SELECT 1 FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'HRCOMP02'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID;

INSERT INTO #SeedEmployees
SELECT TOP (1) e.BusinessEntityID, 16, N'LEAD03', '2025-05-01', NULL, NULL, NULL, N'Pending'
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID AND edh.EndDate IS NULL AND edh.DepartmentID = 16
WHERE e.CurrentFlag = 1
  AND NOT EXISTS (
        SELECT 1
        FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'LEAD03'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
  AND NOT EXISTS (
        SELECT 1
        FROM #SeedEmployees AS s
        WHERE s.BusinessEmployeeID = e.BusinessEntityID
          AND s.CourseCode = N'LEAD03'
          AND s.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID;

/* Well-known employee 288 self-service demo row when present */
IF EXISTS (SELECT 1 FROM HumanResources.Employee WHERE BusinessEntityID = 288 AND CurrentFlag = 1)
AND NOT EXISTS (SELECT 1 FROM #SeedEmployees WHERE BusinessEmployeeID = 288 AND CourseCode = N'SAFETY01')
BEGIN
    DECLARE @Dept288 SMALLINT;
    SELECT TOP (1) @Dept288 = DepartmentID
    FROM HumanResources.EmployeeDepartmentHistory
    WHERE BusinessEntityID = 288 AND EndDate IS NULL
    ORDER BY StartDate DESC;

    INSERT INTO #SeedEmployees
    VALUES (288, @Dept288, N'SAFETY01', '2024-01-15', '2024-02-01', 88.00, '2024-06-01', N'Expired');
END

INSERT INTO HRTrainingOps.TrainingRequests
    (BusinessEmployeeID, CourseCode, EnrollmentDate, ExamDate, Score,
     CertificationExpiryDate, RequestStatus, DepartmentID)
SELECT
    s.BusinessEmployeeID,
    s.CourseCode,
    s.EnrollmentDate,
    s.ExamDate,
    s.Score,
    s.ExpiryDate,
    s.RequestStatus,
    s.DepartmentID
FROM #SeedEmployees AS s
WHERE
    /* Skip exact duplicate seed rows (any status) */
    NOT EXISTS (
        SELECT 1
        FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = s.BusinessEmployeeID
          AND tr.CourseCode = s.CourseCode
          AND tr.RequestStatus = s.RequestStatus
          AND tr.EnrollmentDate = s.EnrollmentDate
    )
    /* Respect UX_TrainingRequests_ActiveEnrollment (one Pending/Completed per emp+course) */
    AND NOT (
        s.RequestStatus IN (N'Pending', N'Completed')
        AND EXISTS (
            SELECT 1
            FROM HRTrainingOps.TrainingRequests AS tr
            WHERE tr.BusinessEmployeeID = s.BusinessEmployeeID
              AND tr.CourseCode = s.CourseCode
              AND tr.RequestStatus IN (N'Pending', N'Completed')
        )
    );

DROP TABLE #SeedEmployees;
GO

/* Extra pending rows for filtered-index IO demo (same courses, more employees) */
INSERT INTO HRTrainingOps.TrainingRequests
    (BusinessEmployeeID, CourseCode, EnrollmentDate, RequestStatus, DepartmentID)
SELECT TOP (15)
    e.BusinessEntityID,
    N'CYBER04',
    DATEADD(DAY, -ABS(CHECKSUM(NEWID()) % 60), CAST(SYSDATETIME() AS DATE)),
    N'Pending',
    edh.DepartmentID
FROM HumanResources.Employee AS e
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh
    ON edh.BusinessEntityID = e.BusinessEntityID
   AND edh.EndDate IS NULL
WHERE e.CurrentFlag = 1
  AND NOT EXISTS (
        SELECT 1
        FROM HRTrainingOps.TrainingRequests AS tr
        WHERE tr.BusinessEmployeeID = e.BusinessEntityID
          AND tr.CourseCode = N'CYBER04'
          AND tr.RequestStatus IN (N'Pending', N'Completed')
      )
ORDER BY e.BusinessEntityID;
GO

/* =========================================================
   4) Expired certification queue
   ========================================================= */
PRINT '--- 4) ExpiredCertificationQueue ---';

INSERT INTO HRTrainingOps.ExpiredCertificationQueue
    (TrainingRequestID, BusinessEmployeeID, CourseCode, ExpiryDate, DaysOverdue, QueueStatus)
SELECT
    tr.TrainingRequestID,
    tr.BusinessEmployeeID,
    tr.CourseCode,
    tr.CertificationExpiryDate,
    DATEDIFF(DAY, tr.CertificationExpiryDate, CAST(SYSDATETIME() AS DATE)),
    N'Pending Review'
FROM HRTrainingOps.TrainingRequests AS tr
WHERE tr.CertificationExpiryDate IS NOT NULL
  AND tr.CertificationExpiryDate < CAST(SYSDATETIME() AS DATE)
  AND tr.RequestStatus IN (N'Expired', N'Completed', N'Failed')
  AND NOT EXISTS (
        SELECT 1
        FROM HRTrainingOps.ExpiredCertificationQueue AS q
        WHERE q.TrainingRequestID = tr.TrainingRequestID
      );

/* Mark source Completed rows as Expired when past expiry (keeps status consistent) */
UPDATE HRTrainingOps.TrainingRequests
SET RequestStatus = N'Expired'
WHERE RequestStatus = N'Completed'
  AND CertificationExpiryDate IS NOT NULL
  AND CertificationExpiryDate < CAST(SYSDATETIME() AS DATE);
GO

/* =========================================================
   5) Sample review + notifications (one resolved demo path)
   ========================================================= */
PRINT '--- 5) CertificationReleaseReview + NotificationLog ---';

DECLARE @DemoQueueID INT;
DECLARE @DemoRequestID INT;
DECLARE @DemoEmpID INT;
DECLARE @DemoCourse NVARCHAR(10);

SELECT TOP (1)
    @DemoQueueID = q.QueueID,
    @DemoRequestID = q.TrainingRequestID,
    @DemoEmpID = q.BusinessEmployeeID,
    @DemoCourse = q.CourseCode
FROM HRTrainingOps.ExpiredCertificationQueue AS q
WHERE q.QueueStatus = N'Pending Review'
ORDER BY q.DaysOverdue DESC;

IF @DemoQueueID IS NOT NULL
   AND NOT EXISTS (
        SELECT 1 FROM HRTrainingOps.CertificationReleaseReview
        WHERE TrainingRequestID = @DemoRequestID
   )
BEGIN
    UPDATE HRTrainingOps.ExpiredCertificationQueue
    SET QueueStatus = N'Notified'
    WHERE QueueID = @DemoQueueID
      AND QueueStatus = N'Pending Review';

    INSERT INTO HRTrainingOps.CertificationReleaseReview
        (TrainingRequestID, ReviewDecision, ReviewNotes, ReviewedBy)
    VALUES
        (@DemoRequestID, N'Re-Enroll', N'Phase III sample review — re-enroll required.', N'HR_Manager_Demo');

    UPDATE HRTrainingOps.ExpiredCertificationQueue
    SET QueueStatus = N'Resolved'
    WHERE QueueID = @DemoQueueID;

    INSERT INTO HRTrainingOps.NotificationLog
        (BusinessEmployeeID, NotificationType, MessageText)
    VALUES
        (@DemoEmpID, N'Re-Enroll',
         N'Sample review: re-enroll in ' + @DemoCourse + N' (QueueID=' + CAST(@DemoQueueID AS NVARCHAR(20)) + N').');
END

/* General enrollment confirmations for pending rows missing a notice */
INSERT INTO HRTrainingOps.NotificationLog (BusinessEmployeeID, NotificationType, MessageText)
SELECT TOP (10)
    tr.BusinessEmployeeID,
    N'Enrollment Confirmation',
    N'Seed notice: enrolled in ' + tr.CourseCode + N' on ' + CONVERT(NVARCHAR(10), tr.EnrollmentDate, 120)
FROM HRTrainingOps.TrainingRequests AS tr
WHERE tr.RequestStatus = N'Pending'
  AND NOT EXISTS (
        SELECT 1
        FROM HRTrainingOps.NotificationLog AS n
        WHERE n.BusinessEmployeeID = tr.BusinessEmployeeID
          AND n.NotificationType = N'Enrollment Confirmation'
          AND n.MessageText LIKE N'%' + tr.CourseCode + N'%'
      );
GO

/* =========================================================
   6) Validation summary
   ========================================================= */
PRINT '--- 6) Row counts ---';
SELECT N'TrainingCourse' AS Entity, COUNT(*) AS RowCnt FROM HRTrainingOps.TrainingCourse
UNION ALL SELECT N'DepartmentTrainingRequirement', COUNT(*) FROM HRTrainingOps.DepartmentTrainingRequirement
UNION ALL SELECT N'TrainingRequests', COUNT(*) FROM HRTrainingOps.TrainingRequests
UNION ALL SELECT N'ExpiredCertificationQueue', COUNT(*) FROM HRTrainingOps.ExpiredCertificationQueue
UNION ALL SELECT N'CertificationReleaseReview', COUNT(*) FROM HRTrainingOps.CertificationReleaseReview
UNION ALL SELECT N'NotificationLog', COUNT(*) FROM HRTrainingOps.NotificationLog
UNION ALL SELECT N'ErrorLog', COUNT(*) FROM HRTrainingOps.ErrorLog;

SELECT RequestStatus, COUNT(*) AS Cnt
FROM HRTrainingOps.TrainingRequests
GROUP BY RequestStatus
ORDER BY RequestStatus;
GO

PRINT '========== test_data.sql complete ==========';
PRINT 'Next: run optimization\indexes.sql then security\test_cases.sql.';
GO
