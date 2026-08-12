/*
    HRTrainingOps - Phase III
    Script : optimization/indexes.sql
    Purpose: Create required clustered / nonclustered / filtered INCLUDE indexes
    Owner  : Dhruv Patel (Security & Optimization Lead)

    Index plan:
      1. Clustered  — PK_TrainingRequests (created in schema/03_training_requests.sql)
      2. Nonclustered — IX_ExpiredQueue_EmployeeExpiry
      3. Filtered INCLUDE — IX_TrainingRequests_Pending

    Optional supporting indexes for compliance / reporting are included below
    and labeled clearly so they can be omitted for a minimal demo.
*/
USE AdventureWorks2022;
GO

PRINT '=== HRTrainingOps Phase III — Index Deployment ===';
GO

/* ------------------------------------------------------------------
   1) CLUSTERED INDEX (already deployed with Phase I schema)
      Documented here for instructor checklist completeness.
   ------------------------------------------------------------------ */
IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'HRTrainingOps.TrainingRequests')
      AND name = N'PK_TrainingRequests'
      AND type_desc = N'CLUSTERED'
)
    PRINT 'Clustered: PK_TrainingRequests on TrainingRequests(TrainingRequestID) — OK.';
ELSE
    PRINT 'WARNING: PK_TrainingRequests clustered index not found. Redeploy schema.';
GO

/* ------------------------------------------------------------------
   2) NONCLUSTERED INDEX
      Speeds queue lookups / expiry scans by employee + expiry date.
   ------------------------------------------------------------------ */
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'HRTrainingOps.ExpiredCertificationQueue')
      AND name = N'IX_ExpiredQueue_EmployeeExpiry'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ExpiredQueue_EmployeeExpiry
        ON HRTrainingOps.ExpiredCertificationQueue (BusinessEmployeeID, ExpiryDate)
        INCLUDE (CourseCode, QueueStatus, DaysOverdue);

    PRINT 'Created: IX_ExpiredQueue_EmployeeExpiry.';
END
ELSE
    PRINT 'Exists: IX_ExpiredQueue_EmployeeExpiry.';
GO

/* ------------------------------------------------------------------
   3) FILTERED NONCLUSTERED INDEX WITH INCLUDE
      Targets pending enrollments used by clerk / manager follow-up reports.
   ------------------------------------------------------------------ */
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'HRTrainingOps.TrainingRequests')
      AND name = N'IX_TrainingRequests_Pending'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_TrainingRequests_Pending
        ON HRTrainingOps.TrainingRequests (EnrollmentDate)
        INCLUDE (CourseCode, BusinessEmployeeID, DepartmentID)
        WHERE RequestStatus = N'Pending';

    PRINT 'Created: IX_TrainingRequests_Pending (filtered + INCLUDE).';
END
ELSE
    PRINT 'Exists: IX_TrainingRequests_Pending.';
GO

/* ------------------------------------------------------------------
   Supporting indexes (recommended for compliance report demos)
   ------------------------------------------------------------------ */
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'HRTrainingOps.TrainingRequests')
      AND name = N'IX_TrainingRequests_DeptStatus'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_TrainingRequests_DeptStatus
        ON HRTrainingOps.TrainingRequests (DepartmentID, RequestStatus)
        INCLUDE (CourseCode, EnrollmentDate, ExamDate, Score, CertificationExpiryDate, BusinessEmployeeID);

    PRINT 'Created: IX_TrainingRequests_DeptStatus (supporting).';
END
ELSE
    PRINT 'Exists: IX_TrainingRequests_DeptStatus.';
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'HRTrainingOps.TrainingRequests')
      AND name = N'IX_TrainingRequests_Expiry'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_TrainingRequests_Expiry
        ON HRTrainingOps.TrainingRequests (CertificationExpiryDate, RequestStatus)
        INCLUDE (BusinessEmployeeID, CourseCode);

    PRINT 'Created: IX_TrainingRequests_Expiry (supporting).';
END
ELSE
    PRINT 'Exists: IX_TrainingRequests_Expiry.';
GO

/* Verify Phase III indexes */
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.has_filter AS IsFiltered,
    i.filter_definition AS FilterDefinition
FROM sys.indexes AS i
INNER JOIN sys.tables AS t
    ON t.object_id = i.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'HRTrainingOps'
  AND i.name IN (
        N'PK_TrainingRequests',
        N'IX_ExpiredQueue_EmployeeExpiry',
        N'IX_TrainingRequests_Pending',
        N'IX_TrainingRequests_DeptStatus',
        N'IX_TrainingRequests_Expiry'
      )
ORDER BY t.name, i.name;
GO

PRINT '=== Phase III index deployment complete ===';
PRINT 'Next: run optimization\index_performance_compare.sql for pre/post IO comparison.';
GO
