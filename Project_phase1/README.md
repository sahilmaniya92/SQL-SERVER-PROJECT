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

## Repository Structure

```
PROJECT/
├── schema/                 Phase I - CREATE TABLE scripts
├── views/                  Phase II
├── procedures/             Phase II
├── functions/              Phase II
├── triggers/               Phase II
├── security/               Phase II-III
├── optimization/           Phase III
├── diagrams/
├── screenshots/
├── test_data.sql           Phase III
├── final_script.sql        Phase III
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
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\schema"
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

## Phase I Deliverables

- [x] Business case and roles defined — see proposal document
- [x] Full ERD — `diagrams/hrtrainingops_erd.drawio`
- [x] Normalized CREATE TABLE scripts — `schema/` folder
- [x] Constraints and relational integrity — PK, FK, CHECK, UNIQUE in each script
- [ ] GitHub private repository initialized
- [ ] ERD exported to PDF for Blackboard

---

## Collaboration

- One private GitHub repository per group
- Minimum 5 meaningful commits per student
- Feature branches and Pull Request review before merge to `main`

---

## Academic Integrity

All code is authored by the group. Every member must be able to explain all components during instructor review.
