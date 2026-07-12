/*
    HRTrainingOps - Phase II
    Script : deploy_phase2.sql
    Purpose: Deploy all Phase II objects in dependency order
    Owner  : Parth Patel (Logic Developer) / Team

    Usage (SSMS):
      1. Enable SQLCMD Mode (Query -> SQLCMD Mode)
      2. Update :setvar ScriptRoot to your Project_phase1 folder path
      3. Ensure Phase I schema is already deployed
      4. Execute this script
*/
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\Project_phase1"

USE AdventureWorks2022;
GO

PRINT '=== HRTrainingOps Phase II - Logic & Security Deployment ===';
GO

/* Functions first (views/procedures depend on them) */
:r $(ScriptRoot)\functions\fn_TrainingScoreClass.sql
:r $(ScriptRoot)\functions\fn_GetEmployeeTrainingData.sql

/* Views */
:r $(ScriptRoot)\views\vEmployeeTrainingSummary.sql
:r $(ScriptRoot)\views\vw_PendingCertifications.sql
:r $(ScriptRoot)\views\vw_ManagerDepartmentCompliance.sql
:r $(ScriptRoot)\views\vw_EmployeeSelfService.sql

/* Triggers */
:r $(ScriptRoot)\triggers\trg_TrainingRequests_ValidateEnrollment.sql
:r $(ScriptRoot)\triggers\trg_TrainingRequests_AuditStatusChange.sql
:r $(ScriptRoot)\triggers\trg_ExpiredQueue_StatusTransition.sql

/* Procedures */
:r $(ScriptRoot)\procedures\usp_EnrollEmployeeInCourse.sql
:r $(ScriptRoot)\procedures\usp_GetTrainingRequests.sql
:r $(ScriptRoot)\procedures\usp_ProcessCertificationReview.sql
:r $(ScriptRoot)\procedures\usp_BatchUpdateExpiredCertifications.sql
:r $(ScriptRoot)\procedures\usp_GetDepartmentTrainingStats.sql
:r $(ScriptRoot)\procedures\usp_RunComplianceReport.sql
:r $(ScriptRoot)\procedures\expired_certification_review_cursor.sql
:r $(ScriptRoot)\procedures\usp_DynamicDepartmentNotification.sql

/* Security last */
:r $(ScriptRoot)\security\permissions.sql

PRINT '=== Phase II deployment complete ===';
PRINT 'Next: run security\test_cases.sql to simulate workflows.';
GO
