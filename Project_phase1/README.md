# HRTrainingOps
## Employee Training & Certification Tracker

**Course:** SQL Server Database Development  
**Platform:** Microsoft SQL Server 2016 · T-SQL only  
**Database:** AdventureWorks2022  
**Schema:** `HRTrainingOps`

---

## Project Overview

HRTrainingOps is a back-end relational database system for AdventureWorks HR. It tracks employee training enrollments, certification exams, expiry dates, department compliance requirements, and review workflows — implemented entirely in T-SQL with no GUI or frontend.

---

## Team Members

| Name | Student No. | GitHub Username | Role |
|------|-------------|-----------------|------|
| Sahil Maniya | | | Schema Designer |
| Parth Patel | | | Logic Developer |
| Dhruv | | | Security & Optimization Lead |

### Role Responsibilities

| Role | Responsibilities |
|------|------------------|
| **Schema Designer** (Sahil) | ERD, normalization, CREATE TABLE scripts, views, final integration |
| **Logic Developer** (Parth) | Stored procedures, functions, triggers, transactions |
| **Security & Optimization Lead** (Dhruv) | Roles, permissions, indexes, performance analysis, cursors |

All members must understand and be able to explain every project component during the final demo.

---

## Business Case Summary

AdventureWorks HR needs a centralized system to manage training enrollments, certification results, expiry tracking, and compliance reporting. HRTrainingOps adds seven normalized tables in the `HRTrainingOps` schema, linked to existing `HumanResources` and `Person` data.

**User Roles:** HR_Admin · HR_Manager · Training_Clerk · Employee_Client

Full specification: [PROJECT_PROPOSAL_HRTrainingOps.md](PROJECT_PROPOSAL_HRTrainingOps.md)

---

## Schema Overview (Phase I)

| # | Table | Purpose |
|---|-------|---------|
| 1 | `TrainingCourse` | Course catalog |
| 2 | `TrainingRequests` | Employee enrollments and exam results |
| 3 | `DepartmentTrainingRequirement` | Required courses per department |
| 4 | `ExpiredCertificationQueue` | Expired / expiring certifications |
| 5 | `CertificationReleaseReview` | HR review decisions |
| 6 | `NotificationLog` | System notifications |
| 7 | `ErrorLog` | Errors and audit entries |

**ERD:** [diagrams/hrtrainingops_erd.drawio](diagrams/hrtrainingops_erd.drawio) — professional Crow's Foot diagram; export to PDF for Blackboard. See [diagrams/ERD_README.md](diagrams/ERD_README.md).

---

## Phase II — Logic & Security

| Area | Objects |
|------|---------|
| **Functions** | `fn_TrainingScoreClass` (scalar), `fn_GetEmployeeTrainingData` (inline TVF) |
| **Views** | `vEmployeeTrainingSummary`, `vw_PendingCertifications`, `vw_ManagerDepartmentCompliance`, `vw_EmployeeSelfService` |
| **Triggers** | Enrollment validation, status audit, queue status transitions |
| **Procedures** | 6 core procs + static cursor + dynamic cursor (includes dynamic SQL compliance report) |
| **Security** | 4 roles with GRANT / REVOKE / DENY — `security/permissions.sql` |
| **Tests** | Workflow + permission simulations — `security/test_cases.sql` |

### Demo logins (created by permissions.sql)

| Login | Role | Notes |
|-------|------|-------|
| `HRTO_Admin` | HR_Admin | Full schema access |
| `HRTO_Manager` | HR_Manager | Reviews + compliance |
| `HRTO_Mgr_7` | HR_Manager | Row-filter demo for Department 7 |
| `HRTO_Clerk` | Training_Clerk | Enroll/update; DENY review & DELETE |
| `HRTO_Emp_288` | Employee_Client | Self-service view for employee 288 |

---

## Repository Structure

```
Project_phase1/
├── schema/                 Phase I - CREATE TABLE scripts
├── functions/              Phase II - scalar + TVF
├── views/                  Phase II - reporting + row-level security
├── triggers/               Phase II - DML enforcement
├── procedures/             Phase II - workflows, dynamic SQL, cursors
├── security/               Phase II - permissions.sql, test_cases.sql
├── deploy_phase2.sql       Phase II master deploy (SQLCMD)
├── optimization/           Phase III
├── diagrams/
├── Screenshot/
├── PROJECT_PROPOSAL_HRTrainingOps.md
└── README.md
```

---

## Phase I — How to Run Schema Scripts

### Prerequisites

- Microsoft SQL Server 2016 (vApp)
- SSMS with **AdventureWorks2022** restored
- SQLCMD Mode enabled for master deploy script

### Option A — Deploy all schema scripts (recommended)

1. Open `schema/deploy_schema.sql` in SSMS
2. Enable **SQLCMD Mode** (`Query` → `SQLCMD Mode`)
3. Update the path if your folder is different:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\Project_phase1\schema"
```

4. Execute the script

### Option B — Run scripts individually

Execute in this order:

| Order | Script |
|-------|--------|
| 1 | `schema/01_create_schema.sql` |
| 2 | `schema/02_training_course.sql` |
| 3 | `schema/03_training_requests.sql` |
| 4 | `schema/04_department_training_requirement.sql` |
| 5 | `schema/05_expired_certification_queue.sql` |
| 6 | `schema/06_certification_release_review.sql` |
| 7 | `schema/07_notification_log.sql` |
| 8 | `schema/08_error_log.sql` |

### Verify deployment

```sql
USE AdventureWorks2022;
GO

SELECT s.name AS SchemaName, t.name AS TableName
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = N'HRTrainingOps'
ORDER BY t.name;
GO
```

Expected: **7 tables** listed.

---

## Phase II — How to Deploy Logic & Security

### Option A — Master script (recommended)

1. Open `deploy_phase2.sql` in SSMS
2. Enable **SQLCMD Mode**
3. Set ScriptRoot to your `Project_phase1` folder:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\Project_phase1"
```

4. Execute the script (deploys functions → views → triggers → procedures → permissions)

### Option B — Manual order

1. `functions/` (scalar first, then TVF)
2. `views/`
3. `triggers/`
4. `procedures/`
5. `security/permissions.sql`

### Run workflow tests

```sql
-- As dbo / sysadmin after Phase II deploy:
:r D:\ITS\SEM-2\SQL SERVER\PROJECT\Project_phase1\security\test_cases.sql
```

Or open and execute `security/test_cases.sql` in SSMS.

---

## Phase I Deliverables

- [x] Business case and roles defined — see proposal document
- [x] Full ERD — `diagrams/hrtrainingops_erd.drawio`
- [x] Normalized CREATE TABLE scripts — `schema/` folder
- [x] Constraints and relational integrity — PK, FK, CHECK, UNIQUE in each script
- [ ] GitHub private repository initialized
- [ ] ERD exported to PDF for Blackboard

## Phase II Deliverables

- [x] Stored procedures, triggers, functions, views
- [x] Security and permissions — `security/permissions.sql`
- [x] Test scripts simulating user workflows — `security/test_cases.sql`
- [x] Dynamic SQL (`usp_RunComplianceReport`) and cursor procedures
- [x] Structured GitHub commit history

---

## Collaboration

- One private GitHub repository per group
- Minimum 5 meaningful commits per student
- Feature branches and Pull Request review before merge to `main`

---

## Academic Integrity

All code is authored by the group. Every member must be able to explain all components during instructor review.
