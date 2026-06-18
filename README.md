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
│   ├── schema/                         Phase I - CREATE TABLE scripts
│   ├── diagrams/                       ERD (draw.io + PNG/JPG)
│   ├── Screenshot/                     Phase I proof screenshots
│   ├── PROJECT_PROPOSAL_HRTrainingOps.md
│   └── README.md
├── views/                              Phase II (planned)
├── procedures/                         Phase II (planned)
├── functions/                          Phase II (planned)
├── triggers/                           Phase II (planned)
├── security/                           Phase II-III (planned)
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

**Proposal:** [Project_phase1/PROJECT_PROPOSAL_HRTrainingOps.md](Project_phase1/PROJECT_PROPOSAL_HRTrainingOps.md)

**ERD:** [Project_phase1/diagrams/hrtrainingops_erd.drawio](Project_phase1/diagrams/hrtrainingops_erd.drawio)

---

## Phase I Deliverables

- [x] Business case and roles defined
- [x] Full ERD (draw.io + exported images)
- [x] Normalized CREATE TABLE scripts (7 tables)
- [x] Constraints and relational integrity
- [x] GitHub repository initialized

---

## Academic Integrity

All code is authored by the group. Every member must be able to explain all components during instructor review.
