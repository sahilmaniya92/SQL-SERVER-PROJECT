/*
    HRTrainingOps - Phase III
    Script : final_script.sql
    Purpose: Master deployment from a clean AdventureWorks2022 environment
    Owner  : Sahil Maniya (Schema Designer) / Team

    Usage (SSMS):
      1. Restore / attach AdventureWorks2022
      2. Enable SQLCMD Mode (Query -> SQLCMD Mode)
      3. Update :setvar ProjectRoot to your local clone path
      4. Execute this script as sysadmin (permissions create logins)
      5. Optional demo: security\test_cases.sql and
         optimization\index_performance_compare.sql
*/
:setvar ProjectRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT"

USE AdventureWorks2022;
GO

PRINT '############################################################';
PRINT '### HRTrainingOps FINAL DEPLOYMENT (Phases I + II + III) ###';
PRINT '############################################################';
GO

/* =========================================================
   PHASE I — Schema
   ========================================================= */
PRINT '>>> PHASE I: Schema';
GO

:r $(ProjectRoot)\schema\01_create_schema.sql
:r $(ProjectRoot)\schema\02_training_course.sql
:r $(ProjectRoot)\schema\03_training_requests.sql
:r $(ProjectRoot)\schema\04_department_training_requirement.sql
:r $(ProjectRoot)\schema\05_expired_certification_queue.sql
:r $(ProjectRoot)\schema\06_certification_release_review.sql
:r $(ProjectRoot)\schema\07_notification_log.sql
:r $(ProjectRoot)\schema\08_error_log.sql

PRINT '>>> PHASE I complete';
GO

/* =========================================================
   PHASE II — Functions, views, triggers, procedures, security
   ========================================================= */
PRINT '>>> PHASE II: Logic & Security';
GO

:r $(ProjectRoot)\functions\fn_TrainingScoreClass.sql
:r $(ProjectRoot)\functions\fn_GetEmployeeTrainingData.sql

:r $(ProjectRoot)\views\vEmployeeTrainingSummary.sql
:r $(ProjectRoot)\views\vw_PendingCertifications.sql
:r $(ProjectRoot)\views\vw_ManagerDepartmentCompliance.sql
:r $(ProjectRoot)\views\vw_EmployeeSelfService.sql

:r $(ProjectRoot)\triggers\trg_TrainingRequests_ValidateEnrollment.sql
:r $(ProjectRoot)\triggers\trg_TrainingRequests_AuditStatusChange.sql
:r $(ProjectRoot)\triggers\trg_ExpiredQueue_StatusTransition.sql

:r $(ProjectRoot)\procedures\usp_EnrollEmployeeInCourse.sql
:r $(ProjectRoot)\procedures\usp_GetTrainingRequests.sql
:r $(ProjectRoot)\procedures\usp_ProcessCertificationReview.sql
:r $(ProjectRoot)\procedures\usp_BatchUpdateExpiredCertifications.sql
:r $(ProjectRoot)\procedures\usp_GetDepartmentTrainingStats.sql
:r $(ProjectRoot)\procedures\usp_RunComplianceReport.sql
:r $(ProjectRoot)\procedures\expired_certification_review_cursor.sql
:r $(ProjectRoot)\procedures\usp_DynamicDepartmentNotification.sql

:r $(ProjectRoot)\security\permissions.sql

PRINT '>>> PHASE II complete';
GO

/* =========================================================
   PHASE III — Sample data then indexes
   (Load data first so index builds reflect realistic distributions;
    IO compare script can still be run before/after by dropping NCIs.)
   ========================================================= */
PRINT '>>> PHASE III: Sample data';
GO

:r $(ProjectRoot)\test_data.sql

PRINT '>>> PHASE III: Indexes';
GO

:r $(ProjectRoot)\optimization\indexes.sql

PRINT '############################################################';
PRINT '### FINAL DEPLOYMENT COMPLETE                            ###';
PRINT '############################################################';
PRINT 'Validate objects:';
PRINT '  SELECT name FROM sys.tables t JOIN sys.schemas s ON ... HRTrainingOps';
PRINT 'Demo next steps:';
PRINT '  1) security\test_cases.sql          — workflows + permissions';
PRINT '  2) optimization\index_performance_compare.sql — IO / SHOWPLAN';
PRINT '  3) Capture screenshots under Screenshot\{Sahil|Parth|Dhruv}\';
GO

/* Object inventory for instructor review */
SELECT 'Table' AS ObjectType, t.name AS ObjectName
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = N'HRTrainingOps'
UNION ALL
SELECT 'View', v.name
FROM sys.views AS v
INNER JOIN sys.schemas AS s ON s.schema_id = v.schema_id
WHERE s.name = N'HRTrainingOps'
UNION ALL
SELECT 'Procedure', p.name
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s ON s.schema_id = p.schema_id
WHERE s.name = N'HRTrainingOps'
UNION ALL
SELECT o.type_desc, o.name
FROM sys.objects AS o
INNER JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE s.name = N'HRTrainingOps'
  AND o.type IN (N'FN', N'IF', N'TR')
ORDER BY ObjectType, ObjectName;
GO
