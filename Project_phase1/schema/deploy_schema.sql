/*
    HRTrainingOps - Phase I
    Script : deploy_schema.sql
    Purpose: Deploy all Phase I schema objects in dependency order
    Owner  : Sahil Maniya (Schema Designer)

    Usage (SSMS):
      1. Enable SQLCMD Mode (Query -> SQLCMD Mode)
      2. Update :setvar ScriptRoot to your local schema folder path
      3. Execute this script
*/
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\schema"

USE AdventureWorks2022;
GO

PRINT '=== HRTrainingOps Phase I - Schema Deployment ===';
GO

:r $(ScriptRoot)\01_create_schema.sql
:r $(ScriptRoot)\02_training_course.sql
:r $(ScriptRoot)\03_training_requests.sql
:r $(ScriptRoot)\04_department_training_requirement.sql
:r $(ScriptRoot)\05_expired_certification_queue.sql
:r $(ScriptRoot)\06_certification_release_review.sql
:r $(ScriptRoot)\07_notification_log.sql
:r $(ScriptRoot)\08_error_log.sql

PRINT '=== Phase I schema deployment complete ===';
GO
