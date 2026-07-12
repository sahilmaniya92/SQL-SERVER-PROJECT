/*
    HRTrainingOps - Phase II
    Script : permissions.sql
    Purpose: Create 4 database roles + demo logins/users and GRANT / REVOKE / DENY
    Owner  : Dhruv (Security & Optimization Lead)

    Demo login naming (row-level views):
      HRTO_Mgr_<DepartmentID>  -> vw_ManagerDepartmentCompliance
      HRTO_Emp_<BusinessEntityID> -> vw_EmployeeSelfService
*/
USE master;
GO

/* ---- Server logins (safe to re-run) ---- */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'HRTO_Admin')
    CREATE LOGIN HRTO_Admin WITH PASSWORD = N'HrTo_Admin#2026', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'HRTO_Manager')
    CREATE LOGIN HRTO_Manager WITH PASSWORD = N'HrTo_Mgr#2026', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'HRTO_Clerk')
    CREATE LOGIN HRTO_Clerk WITH PASSWORD = N'HrTo_Clerk#2026', CHECK_POLICY = OFF;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'HRTO_Emp_288')
    CREATE LOGIN HRTO_Emp_288 WITH PASSWORD = N'HrTo_Emp#2026', CHECK_POLICY = OFF;
GO
/* Extra manager login scoped to DepartmentID 7 (Production) for row-level demo */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'HRTO_Mgr_7')
    CREATE LOGIN HRTO_Mgr_7 WITH PASSWORD = N'HrTo_Mgr7#2026', CHECK_POLICY = OFF;
GO

USE AdventureWorks2022;
GO

/* ---- Database users ---- */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HRTO_Admin')
    CREATE USER HRTO_Admin FOR LOGIN HRTO_Admin;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HRTO_Manager')
    CREATE USER HRTO_Manager FOR LOGIN HRTO_Manager;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HRTO_Clerk')
    CREATE USER HRTO_Clerk FOR LOGIN HRTO_Clerk;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HRTO_Emp_288')
    CREATE USER HRTO_Emp_288 FOR LOGIN HRTO_Emp_288;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HRTO_Mgr_7')
    CREATE USER HRTO_Mgr_7 FOR LOGIN HRTO_Mgr_7;
GO

/* ---- Roles ---- */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HR_Admin' AND type = N'R')
    CREATE ROLE HR_Admin AUTHORIZATION dbo;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HR_Manager' AND type = N'R')
    CREATE ROLE HR_Manager AUTHORIZATION dbo;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'Training_Clerk' AND type = N'R')
    CREATE ROLE Training_Clerk AUTHORIZATION dbo;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'Employee_Client' AND type = N'R')
    CREATE ROLE Employee_Client AUTHORIZATION dbo;
GO

/* ---- Role membership ---- */
ALTER ROLE HR_Admin ADD MEMBER HRTO_Admin;
ALTER ROLE HR_Manager ADD MEMBER HRTO_Manager;
ALTER ROLE HR_Manager ADD MEMBER HRTO_Mgr_7;
ALTER ROLE Training_Clerk ADD MEMBER HRTO_Clerk;
ALTER ROLE Employee_Client ADD MEMBER HRTO_Emp_288;
GO

/* =========================================================
   HR_Admin — full control of HRTrainingOps objects
   ========================================================= */
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::HRTrainingOps TO HR_Admin;
GRANT EXECUTE ON SCHEMA::HRTrainingOps TO HR_Admin;
GRANT ALTER ANY ROLE TO HRTO_Admin;
GO

/* =========================================================
   HR_Manager — read + review workflow + compliance reports
   ========================================================= */
GRANT SELECT ON HRTrainingOps.TrainingCourse TO HR_Manager;
GRANT SELECT ON HRTrainingOps.TrainingRequests TO HR_Manager;
GRANT SELECT ON HRTrainingOps.DepartmentTrainingRequirement TO HR_Manager;
GRANT SELECT ON HRTrainingOps.ExpiredCertificationQueue TO HR_Manager;
GRANT SELECT ON HRTrainingOps.CertificationReleaseReview TO HR_Manager;
GRANT SELECT ON HRTrainingOps.NotificationLog TO HR_Manager;
GRANT SELECT ON HRTrainingOps.ErrorLog TO HR_Manager;

GRANT SELECT ON HRTrainingOps.vEmployeeTrainingSummary TO HR_Manager;
GRANT SELECT ON HRTrainingOps.vw_PendingCertifications TO HR_Manager;
GRANT SELECT ON HRTrainingOps.vw_ManagerDepartmentCompliance TO HR_Manager;

GRANT EXECUTE ON HRTrainingOps.usp_GetTrainingRequests TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.usp_ProcessCertificationReview TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.usp_RunComplianceReport TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.usp_GetDepartmentTrainingStats TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.usp_BatchUpdateExpiredCertifications TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.usp_ProcessExpiryQueueWithCursor TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.usp_DynamicDepartmentNotification TO HR_Manager;
GRANT EXECUTE ON HRTrainingOps.fn_TrainingScoreClass TO HR_Manager;
GRANT SELECT ON HRTrainingOps.fn_GetEmployeeTrainingData TO HR_Manager;

/* Limited UPDATE on queue for review progression */
GRANT UPDATE ON HRTrainingOps.ExpiredCertificationQueue TO HR_Manager;
GRANT INSERT ON HRTrainingOps.CertificationReleaseReview TO HR_Manager;
GRANT INSERT ON HRTrainingOps.NotificationLog TO HR_Manager;
GRANT INSERT ON HRTrainingOps.ErrorLog TO HR_Manager;
GRANT UPDATE ON HRTrainingOps.TrainingRequests TO HR_Manager;
GO

/* =========================================================
   Training_Clerk — enroll / update scores; NO delete / NO review
   ========================================================= */
GRANT SELECT, INSERT, UPDATE ON HRTrainingOps.TrainingCourse TO Training_Clerk;
GRANT SELECT, INSERT, UPDATE ON HRTrainingOps.TrainingRequests TO Training_Clerk;
GRANT SELECT, INSERT, UPDATE ON HRTrainingOps.DepartmentTrainingRequirement TO Training_Clerk;
GRANT SELECT, INSERT ON HRTrainingOps.ExpiredCertificationQueue TO Training_Clerk;
GRANT SELECT ON HRTrainingOps.NotificationLog TO Training_Clerk;
GRANT INSERT ON HRTrainingOps.NotificationLog TO Training_Clerk;
GRANT INSERT ON HRTrainingOps.ErrorLog TO Training_Clerk;

GRANT SELECT ON HRTrainingOps.vEmployeeTrainingSummary TO Training_Clerk;
GRANT SELECT ON HRTrainingOps.vw_PendingCertifications TO Training_Clerk;

GRANT EXECUTE ON HRTrainingOps.usp_EnrollEmployeeInCourse TO Training_Clerk;
GRANT EXECUTE ON HRTrainingOps.usp_GetTrainingRequests TO Training_Clerk;
GRANT EXECUTE ON HRTrainingOps.usp_BatchUpdateExpiredCertifications TO Training_Clerk;
GRANT EXECUTE ON HRTrainingOps.fn_TrainingScoreClass TO Training_Clerk;
GRANT SELECT ON HRTrainingOps.fn_GetEmployeeTrainingData TO Training_Clerk;

/* Explicit denies for clerk */
DENY DELETE ON HRTrainingOps.TrainingRequests TO Training_Clerk;
DENY DELETE ON HRTrainingOps.CertificationReleaseReview TO Training_Clerk;
DENY SELECT, INSERT, UPDATE, DELETE ON HRTrainingOps.CertificationReleaseReview TO Training_Clerk;
DENY EXECUTE ON HRTrainingOps.usp_ProcessCertificationReview TO Training_Clerk;
DENY EXECUTE ON HRTrainingOps.usp_RunComplianceReport TO Training_Clerk;
DENY SELECT ON HRTrainingOps.ErrorLog TO Training_Clerk;
DENY SELECT ON HRTrainingOps.vw_ManagerDepartmentCompliance TO Training_Clerk;
GO

/* =========================================================
   Employee_Client — self-service view only
   ========================================================= */
GRANT SELECT ON HRTrainingOps.vw_EmployeeSelfService TO Employee_Client;
GRANT EXECUTE ON HRTrainingOps.fn_TrainingScoreClass TO Employee_Client;

DENY SELECT ON HRTrainingOps.TrainingRequests TO Employee_Client;
DENY SELECT ON HRTrainingOps.TrainingCourse TO Employee_Client;
DENY SELECT ON HRTrainingOps.ExpiredCertificationQueue TO Employee_Client;
DENY SELECT ON HRTrainingOps.CertificationReleaseReview TO Employee_Client;
DENY SELECT ON HRTrainingOps.NotificationLog TO Employee_Client;
DENY SELECT ON HRTrainingOps.ErrorLog TO Employee_Client;
DENY SELECT ON HRTrainingOps.vEmployeeTrainingSummary TO Employee_Client;
DENY SELECT ON HRTrainingOps.vw_PendingCertifications TO Employee_Client;
DENY SELECT ON HRTrainingOps.vw_ManagerDepartmentCompliance TO Employee_Client;

DENY EXECUTE ON HRTrainingOps.usp_EnrollEmployeeInCourse TO Employee_Client;
DENY EXECUTE ON HRTrainingOps.usp_ProcessCertificationReview TO Employee_Client;
DENY EXECUTE ON HRTrainingOps.usp_RunComplianceReport TO Employee_Client;
DENY EXECUTE ON HRTrainingOps.usp_BatchUpdateExpiredCertifications TO Employee_Client;
DENY EXECUTE ON HRTrainingOps.usp_GetTrainingRequests TO Employee_Client;
GO

/* AdventureWorks catalog access needed by procedures/views under impersonation */
GRANT SELECT ON HumanResources.Employee TO HR_Admin, HR_Manager, Training_Clerk;
GRANT SELECT ON HumanResources.Department TO HR_Admin, HR_Manager, Training_Clerk;
GRANT SELECT ON HumanResources.EmployeeDepartmentHistory TO HR_Admin, HR_Manager, Training_Clerk;
GRANT SELECT ON Person.Person TO HR_Admin, HR_Manager, Training_Clerk, Employee_Client;
GO

PRINT 'HRTrainingOps security roles and permissions applied.';
GO
