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
| Dhruv Patel | | | Security & Optimization Lead |

### Role Responsibilities

| Role | Responsibilities |
|------|------------------|
| **Schema Designer** (Sahil) | ERD, normalization, CREATE TABLE scripts, views, final integration |
| **Logic Developer** (Parth) | Stored procedures, functions, triggers, transactions |
| **Security & Optimization Lead** (Dhruv) | Roles, permissions, indexes, performance analysis, cursors |

---

## Repository Structure

```
SQL-SERVER-PROJECT/
├── schema/                         Phase I  - CREATE TABLE scripts
├── functions/                      Phase II - scalar + inline TVF
├── views/                          Phase II - reporting + row-level security
├── triggers/                       Phase II - DML enforcement
├── procedures/                     Phase II - workflows, dynamic SQL, cursors
├── security/                       Phase II - permissions.sql, test_cases.sql
├── optimization/                   Phase III - indexes + performance notes
├── diagrams/                       ERD (draw.io + images)
├── Screenshot/                     Deployment proof screenshots (Sahil/Parth/Dhruv)
├── deploy_schema.sql               Phase I master deploy (SQLCMD)
├── deploy_phase2.sql               Phase II master deploy (SQLCMD)
├── test_data.sql                   Phase III sample data
├── final_script.sql                Full deploy Phases I–III (SQLCMD)
├── PHASE3_SUMMARY_LOG.md           Phase III summary for instructor review
├── PROJECT_PROPOSAL_HRTrainingOps.md
└── README.md
```

---

## How to Run (From Scratch)

### Prerequisites

- Microsoft SQL Server 2016+ with **AdventureWorks2022** restored
- SSMS connected as **sysadmin** (logins in `permissions.sql`)
- **SQLCMD Mode** enabled for master scripts

### Option A — One-shot full deploy (recommended)

1. Open `final_script.sql`
2. Enable **SQLCMD Mode**
3. Set path and execute:

```sql
:setvar ProjectRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT"
```

Deploys: schema → functions/views/triggers/procedures → permissions → `test_data.sql` → indexes.

### Option B — Phase-by-phase

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `deploy_schema.sql` | Phase I tables |
| 2 | `deploy_phase2.sql` | Phase II logic + security |
| 3 | `test_data.sql` | Sample data |
| 4 | `optimization/indexes.sql` | Phase III indexes |
| 5 | `security/test_cases.sql` | Workflow + permission tests |
| 6 | `optimization/index_performance_compare.sql` | IO / SHOWPLAN compare |

Set ScriptRoot examples:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\schema"   -- deploy_schema.sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT"          -- deploy_phase2.sql
```

---

## Phase Deliverables

| Phase | Status | Contents |
|-------|--------|----------|
| **Phase I** | Done | Schema (7 tables), ERD, proposal |
| **Phase II** | Done | Functions, views, triggers, procedures, security, tests |
| **Phase III** | Done | Indexes, performance compare/notes, `test_data.sql`, `final_script.sql`, summary log |

### Phase III highlights

| Artifact | Description |
|----------|-------------|
| `optimization/indexes.sql` | Clustered PK checklist + NCI + filtered INCLUDE (+ supporting) |
| `optimization/index_performance_compare.sql` | STATISTICS IO/TIME, index usage, SHOWPLAN_TEXT |
| `optimization/index_analysis_notes.md` | Justification + pre/post worksheet |
| `test_data.sql` | Courses, requirements, mixed enrollments, queue, review, notifications |
| `final_script.sql` | Clean-environment master deploy |
| `PHASE3_SUMMARY_LOG.md` | Integration / demo checklist |

### Demo logins (from `security/permissions.sql`)

| Login | Role | Notes |
|-------|------|-------|
| `HRTO_Admin` | HR_Admin | Full schema access |
| `HRTO_Manager` | HR_Manager | Reviews + compliance |
| `HRTO_Mgr_7` | HR_Manager | Row-filter demo for Department 7 |
| `HRTO_Clerk` | Training_Clerk | Enroll/update; DENY review & DELETE |
| `HRTO_Emp_288` | Employee_Client | Self-service view for employee 288 |

---

## Documentation

- **Proposal:** [PROJECT_PROPOSAL_HRTrainingOps.md](PROJECT_PROPOSAL_HRTrainingOps.md)  
- **ERD:** [diagrams/hrtrainingops_erd.drawio](diagrams/hrtrainingops_erd.drawio)  
- **Phase III log:** [PHASE3_SUMMARY_LOG.md](PHASE3_SUMMARY_LOG.md)  
- **Index notes:** [optimization/index_analysis_notes.md](optimization/index_analysis_notes.md)

---

## Academic Integrity

All code is authored by the group. Every member must be able to explain all components during instructor review.
