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
├── diagrams/                       ERD (draw.io + images)
├── Screenshot/                     Deployment proof screenshots
├── deploy_schema.sql               Phase I master deploy (SQLCMD)
├── deploy_phase2.sql               Phase II master deploy (SQLCMD)
├── PROJECT_PROPOSAL_HRTrainingOps.md
└── README.md
```

---

## How to Run (From Scratch)

### Prerequisites

- Microsoft SQL Server 2016+ with **AdventureWorks2022** restored
- SSMS with **SQLCMD Mode** enabled for master deploy scripts

### Step 1 — Deploy Phase I schema

1. Open `deploy_schema.sql`
2. Enable **SQLCMD Mode** (`Query` → `SQLCMD Mode`)
3. Set your local path:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT\schema"
```

4. Execute (`F5`)

### Step 2 — Deploy Phase II logic & security

1. Open `deploy_phase2.sql`
2. Enable **SQLCMD Mode**
3. Set your local path:

```sql
:setvar ScriptRoot "D:\ITS\SEM-2\SQL SERVER\PROJECT"
```

4. Execute (`F5`)

### Step 3 — Run workflow tests

Open and execute `security/test_cases.sql` as `dbo` / sysadmin.

Each function/view/trigger/procedure script also includes **one built-in test case** at the bottom — open any file and run it after its dependencies exist.

---

## Phase Deliverables

| Phase | Status | Contents |
|-------|--------|----------|
| **Phase I** | Done | Schema (7 tables), ERD, proposal |
| **Phase II** | Done | Functions, views, triggers, procedures, security, tests |
| **Phase III** | Planned | Indexes, test data, `final_script.sql` |

**Proposal:** [PROJECT_PROPOSAL_HRTrainingOps.md](PROJECT_PROPOSAL_HRTrainingOps.md)  
**ERD:** [diagrams/hrtrainingops_erd.drawio](diagrams/hrtrainingops_erd.drawio)

---

## Academic Integrity

All code is authored by the group. Every member must be able to explain all components during instructor review.
