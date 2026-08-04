# HRTrainingOps
## Employee Training & Certification Tracker

**Repository:** [github.com/sahilmaniya92/SQL-SERVER-PROJECT](https://github.com/sahilmaniya92/SQL-SERVER-PROJECT)  
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
| Sahil Maniya | | sahilmaniya92 | Schema Designer |
| Parth Patel | | | Logic Developer |
| Dhruv | | | Security & Optimization Lead |

---

## Repository Structure

```
SQL-SERVER-PROJECT/
├── Project_phase1/
│   ├── schema/                         Phase I  - CREATE TABLE scripts
│   ├── functions/                      Phase II - scalar + inline TVF
│   ├── views/                          Phase II - reporting + row-level security
│   ├── triggers/                       Phase II - DML enforcement
│   ├── procedures/                     Phase II - workflows, dynamic SQL, cursors
│   ├── security/                       Phase II - permissions.sql, test_cases.sql
│   ├── deploy_phase2.sql               Phase II master deploy (SQLCMD)
│   ├── diagrams/                       ERD (draw.io + PNG/JPG)
│   ├── PROJECT_PROPOSAL_HRTrainingOps.md
│   └── README.md
├── optimization/                       Phase III (planned)
└── README.md
```

---

## Phase I — Quick Start

1. Open SSMS with **AdventureWorks2022** restored
2. Enable **SQLCMD Mode**
3. Run `Project_phase1/schema/deploy_schema.sql`
4. Update `:setvar ScriptRoot` to your local path:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\Project_phase1\schema"
```

**Full instructions:** [Project_phase1/README.md](Project_phase1/README.md)

---

## Phase II — Logic & Security

### Deploy

1. Deploy Phase I schema first
2. Open `Project_phase1/deploy_phase2.sql` in SSMS
3. Enable **SQLCMD Mode**
4. Set ScriptRoot and execute:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\Project_phase1"
```

5. Run workflow / permission tests:

```sql
-- Open and execute:
Project_phase1/security/test_cases.sql
```

### Deliverables

| Area | Objects |
|------|---------|
| **Functions** | `fn_TrainingScoreClass` (scalar), `fn_GetEmployeeTrainingData` (inline TVF) |
| **Views** | `vEmployeeTrainingSummary`, `vw_PendingCertifications`, `vw_ManagerDepartmentCompliance`, `vw_EmployeeSelfService` |
| **Triggers** | Enrollment validation, status audit, queue status transitions |
| **Procedures** | 6 core procs + static cursor + dynamic cursor (includes dynamic SQL compliance report) |
| **Security** | 4 roles with GRANT / REVOKE / DENY |
| **Tests** | `security/test_cases.sql` — enrollment, review, compliance, permission checks |

### Demo logins

| Login | Role | Notes |
|-------|------|-------|
| `HRTO_Admin` | HR_Admin | Full schema access |
| `HRTO_Manager` | HR_Manager | Reviews + compliance |
| `HRTO_Mgr_7` | HR_Manager | Row-filter demo for Department 7 |
| `HRTO_Clerk` | Training_Clerk | Enroll/update; DENY review & DELETE |
| `HRTO_Emp_288` | Employee_Client | Self-service view for employee 288 |

---

## Status

- [x] **Phase I** — Schema, ERD, proposal, constraints
- [x] **Phase II** — Procedures, functions, views, triggers, security, test scripts
- [ ] **Phase III** — Indexes, test data, `final_script.sql`

**Proposal:** [Project_phase1/PROJECT_PROPOSAL_HRTrainingOps.md](Project_phase1/PROJECT_PROPOSAL_HRTrainingOps.md)

**ERD:** [Project_phase1/diagrams/hrtrainingops_erd.drawio](Project_phase1/diagrams/hrtrainingops_erd.drawio)

---

## Academic Integrity

All code is authored by the group. Every member must be able to explain all components during instructor review.
