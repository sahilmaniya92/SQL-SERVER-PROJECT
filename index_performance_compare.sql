/*
    HRTrainingOps - Phase III
    Script : optimization/index_performance_compare.sql
    Purpose: Compare query cost BEFORE vs AFTER Phase III indexes
    Owner  : Dhruv Patel (Security & Optimization Lead)

    How to demo (recommended):
      A) Fresh schema + test_data, BEFORE indexes.sql:
           - Run SECTION A (baseline)
      B) Run optimization/indexes.sql
      C) Run SECTION B (post-index) and compare Messages / logical reads

      Or run this whole script AFTER indexes exist — SECTION A still
      shows relative plans with indexes, and SECTION C captures SHOWPLAN text.
*/
USE AdventureWorks2022;
GO

SET NOCOUNT ON;
PRINT '========== HRTrainingOps Index Performance Compare ==========';
GO

/* =========================================================
   Shared workload queries (compliance + pending + expiry queue)
   ========================================================= */

PRINT '--- Warmup (discard first-execution cold cache noise) ---';
SELECT COUNT(*) AS PendingRows
FROM HRTrainingOps.TrainingRequests
WHERE RequestStatus = N'Pending';
GO

/* =========================================================
   SECTION A — STATISTICS IO / TIME (measure logical reads)
   ========================================================= */
PRINT '=== SECTION A: STATISTICS IO / TIME ===';
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

PRINT '--- Query 1: Pending enrollments (targets IX_TrainingRequests_Pending) ---';
SELECT
    tr.TrainingRequestID,
    tr.BusinessEmployeeID,
    tr.CourseCode,
    tr.EnrollmentDate,
    tr.DepartmentID
FROM HRTrainingOps.TrainingRequests AS tr
WHERE tr.RequestStatus = N'Pending'
ORDER BY tr.EnrollmentDate DESC;
GO

PRINT '--- Query 2: Compliance by department (targets IX_TrainingRequests_DeptStatus) ---';
SELECT
    tr.DepartmentID,
    tr.CourseCode,
    tr.BusinessEmployeeID,
    tr.RequestStatus,
    tr.EnrollmentDate,
    tr.Score,
    tr.CertificationExpiryDate
FROM HRTrainingOps.TrainingRequests AS tr
WHERE tr.DepartmentID = 7
  AND tr.RequestStatus IN (N'Pending', N'Completed', N'Expired', N'Failed')
ORDER BY tr.CourseCode, tr.BusinessEmployeeID;
GO

PRINT '--- Query 3: Expired queue by employee/expiry (targets IX_ExpiredQueue_EmployeeExpiry) ---';
SELECT
    q.QueueID,
    q.BusinessEmployeeID,
    q.CourseCode,
    q.ExpiryDate,
    q.DaysOverdue,
    q.QueueStatus
FROM HRTrainingOps.ExpiredCertificationQueue AS q
WHERE q.BusinessEmployeeID IS NOT NULL
  AND q.ExpiryDate < CAST(SYSDATETIME() AS DATE)
ORDER BY q.BusinessEmployeeID, q.ExpiryDate;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

/* =========================================================
   SECTION B — Index usage stats (after workload)
   ========================================================= */
PRINT '=== SECTION B: Index usage since last SQL Server restart ===';
SELECT
    OBJECT_NAME(s.object_id) AS TableName,
    i.name AS IndexName,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan
FROM sys.dm_db_index_usage_stats AS s
INNER JOIN sys.indexes AS i
    ON i.object_id = s.object_id
   AND i.index_id = s.index_id
WHERE s.database_id = DB_ID(N'AdventureWorks2022')
  AND OBJECT_SCHEMA_NAME(s.object_id) = N'HRTrainingOps'
  AND i.name IN (
        N'PK_TrainingRequests',
        N'IX_ExpiredQueue_EmployeeExpiry',
        N'IX_TrainingRequests_Pending',
        N'IX_TrainingRequests_DeptStatus',
        N'IX_TrainingRequests_Expiry',
        N'UX_TrainingRequests_ActiveEnrollment'
      )
ORDER BY TableName, IndexName;
GO

/* =========================================================
   SECTION C — Estimated plan text for pending query
   Turn ON, run ONE statement, then turn OFF (SSMS Messages / results).
   ========================================================= */
PRINT '=== SECTION C: SHOWPLAN_TEXT for pending-enrollment query ===';
PRINT 'Review estimated operators — seek on IX_TrainingRequests_Pending is expected after indexing.';
GO

SET SHOWPLAN_TEXT ON;
GO

SELECT
    tr.TrainingRequestID,
    tr.BusinessEmployeeID,
    tr.CourseCode,
    tr.EnrollmentDate
FROM HRTrainingOps.TrainingRequests AS tr
WHERE tr.RequestStatus = N'Pending';
GO

SET SHOWPLAN_TEXT OFF;
GO

PRINT '========== Performance compare script complete ==========';
PRINT 'Record logical reads from Messages pane into index_analysis_notes.md.';
GO
