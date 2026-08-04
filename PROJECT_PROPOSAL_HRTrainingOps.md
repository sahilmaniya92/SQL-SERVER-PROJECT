# Course Project Specification Document
## Employee Training & Certification Tracker (HRTrainingOps)

---

| Field | Value |
|-------|-------|
| **Project Title** | Employee Training & Certification Tracker |
| **System Name** | HRTrainingOps |
| **Course** | SQL Server Database Development |
| **Platform** | Microsoft SQL Server 2016 · T-SQL only |
| **Host Database** | AdventureWorks2022 (custom `HRTrainingOps` schema) |
| **Team Size** | 3 Members |
| **Team Members** | Sahil Maniya, Parth Patel, Dhruv |
| **Document Version** | 2.0 |

---

## 1. Introduction

This project challenges our team to design, implement, and deliver a fully functional SQL Server database system using **Microsoft SQL Server 2016** and **Transact-SQL (T-SQL)** exclusively. We will simulate a real-world HR training and certification scenario and implement a **normalized, secure, and optimized** back-end relational database system — with **no GUI, no ORMs, and no frontend**.

This course project is a core deliverable reflecting complete understanding of relational database systems: schema planning, logic development, transaction control, security, optimization, and system integration.

**Chosen Business Scenario:** Employee Training & Certification Tracker for AdventureWorks HR — an original scenario meeting all course complexity requirements.

---

## 2. Project Objectives

Upon completion of this project, our team will be able to:

| # | Course Objective | How HRTrainingOps Delivers It |
|---|------------------|-------------------------------|
| 1 | Design normalized database schemas reflecting real-world business requirements | 7 interrelated tables in 3NF with PKs, FKs, defaults, and constraints |
| 2 | Implement procedural logic: stored procedures, views, functions, triggers, dynamic SQL | 5+ procedures, 3+ views, 2+ UDFs, 3+ triggers, 1 dynamic SQL procedure |
| 3 | Develop and test transaction controls and concurrency handling | BEGIN/COMMIT/ROLLBACK in enrollment, review, and batch-update workflows |
| 4 | Apply security models using roles, permissions, and privilege enforcement | 4 database roles with GRANT, REVOKE, DENY and row-level views |
| 5 | Optimize database queries using indexing and execution plan analysis | Clustered, non-clustered, and filtered INCLUDE indexes with SHOWPLAN analysis |
| 6 | Demonstrate a fully integrated system using T-SQL scripting only | `final_script.sql` deploys entire system from clean SQL Server environment |

---

## 3. Business Case

### 3.1 Problem Domain

AdventureWorks HR must track employee training enrollments, certification exams, expiry dates, and department compliance. Employee master data exists in `HumanResources` and `Person`, but **no centralized training lifecycle system** exists. HR currently relies on manual tracking, creating compliance risk, delayed renewals, and no audit trail.

**HRTrainingOps** solves this by adding a dedicated schema that manages courses, enrollments, expiry queues, review decisions, notifications, and error logging — integrated with existing AdventureWorks employee data.

### 3.2 Business Problem

| Challenge | Impact |
|-----------|--------|
| No central training register | HR cannot see enrollment and certification status |
| Manual expiry tracking | Certifications expire without timely action |
| No role-based access | Sensitive HR data lacks controlled visibility |
| No audit trail | Review decisions and errors are not logged |
| Poor query performance | Compliance reports slow without proper indexing |

### 3.3 Proposed Solution

A T-SQL-only database layer that:

- Maintains a normalized course catalog and enrollment records
- Enforces business rules through triggers and transactional procedures
- Routes expired certifications through a multi-step review workflow
- Restricts data access by role (Admin, Manager, Clerk, Employee)
- Optimizes reporting with strategic indexes and execution plan validation
- Deploys entirely via `final_script.sql` on SQL Server 2016

### 3.4 Business Benefits

| Benefit | Description |
|---------|-------------|
| Compliance | Automated detection of expired and missing certifications |
| Efficiency | Structured workflows replace manual HR follow-ups |
| Security | Role-based access limits data exposure |
| Auditability | Triggers and log tables capture changes and errors |
| Performance | Indexes improve department and compliance report speed |
| Maintainability | Modular `.sql` scripts with GitHub version history |

---

## 4. Business Case Requirements (Course Compliance)

### 4.1 Interrelated Entities (Minimum 6 — We Have 7)

| # | Entity | Table | Description | Relationships |
|---|--------|-------|-------------|---------------|
| 1 | Training Course | `TrainingCourse` | Course catalog (code, name, validity) | Referenced by enrollments and dept requirements |
| 2 | Training Enrollment | `TrainingRequests` | Employee enrollment and exam results | FK → `TrainingCourse`, AdventureWorks Employee |
| 3 | Department Requirement | `DepartmentTrainingRequirement` | Required courses per department | FK → `TrainingCourse`, Department |
| 4 | Expiry Queue | `ExpiredCertificationQueue` | Expired / expiring certifications | FK → `TrainingRequests` |
| 5 | Certification Review | `CertificationReleaseReview` | HR review decisions | FK → `TrainingRequests` |
| 6 | Notification Log | `NotificationLog` | System notification messages | FK → Employee reference |
| 7 | Error / Audit Log | `ErrorLog` | Errors and system audit entries | Standalone log table |

**ERD:** Included as PDF in Blackboard submission and `diagrams/hrtrainingops_erd.pdf`

### 4.2 User Roles (Minimum 4)

| Role | Description | Key Operations |
|------|-------------|----------------|
| **HR_Admin** | Full system administrator | Create/alter schema objects, manage roles, full CRUD on all tables, run all procedures |
| **HR_Manager** | Department oversight | View department compliance reports, approve/reject certification reviews, run audit reports |
| **Training_Clerk** | Data entry operator | Register enrollments, update exam scores, queue expired certs — **no delete on review tables** |
| **Employee_Client** | End employee (read-only) | View own training history and pending certifications via restricted view only |

### 4.3 User Operations by Role

| Operation | HR_Admin | HR_Manager | Training_Clerk | Employee_Client |
|-----------|:--------:|:----------:|:--------------:|:---------------:|
| Insert enrollment | ✓ | ✗ | ✓ | ✗ |
| Update exam score | ✓ | ✗ | ✓ | ✗ |
| Delete enrollment | ✓ | ✗ | ✗ | ✗ |
| Approve certification review | ✓ | ✓ | ✗ | ✗ |
| View all employee records | ✓ | ✓ (dept only) | ✓ | ✗ |
| View own training record | ✓ | ✓ | ✓ | ✓ |
| Run compliance reports | ✓ | ✓ | ✗ | ✗ |
| Manage security roles | ✓ | ✗ | ✗ | ✗ |
| Run audit / error logs | ✓ | ✓ | ✗ | ✗ |

### 4.4 Business Workflows (Minimum 3)

#### Workflow 1 — Employee Enrollment (Multi-Step Transaction)

1. **Training_Clerk** calls `usp_EnrollEmployeeInCourse`
2. Procedure validates employee is active and course exists
3. **Trigger** `trg_TrainingRequests_ValidateEnrollment` validates enrollment date and duplicate enrollment
4. Transaction commits enrollment; notification row inserted
5. On failure → **ROLLBACK** + entry in `ErrorLog`

**Demonstrates:** Transaction block, validation trigger, TRY/CATCH, Clerk role permissions

#### Workflow 2 — Expired Certification Review (Conditional Logic)

1. Batch procedure identifies expired certifications → inserts into `ExpiredCertificationQueue`
2. **Static cursor** processes each queue item
3. **HR_Manager** calls `usp_ProcessCertificationReview` with decision (Re-Enroll / Waived / Terminated)
4. Multi-step transaction updates queue status, inserts `CertificationReleaseReview`, updates `TrainingRequests`
5. **Trigger** `trg_CertificationReview_AuditInsert` logs review to `ErrorLog` audit section

**Demonstrates:** Cursor, conditional IF/ELSE, multi-table transaction, Manager approval

#### Workflow 3 — Compliance Audit Report (Dynamic SQL + Security)

1. **HR_Manager** executes `usp_RunComplianceReport` with dynamic `@DepartmentName` or `@CourseCode` filter
2. Procedure builds dynamic SQL safely with parameterization
3. **Dynamic cursor** iterates departments for notification generation
4. Manager sees results via `vw_ManagerDepartmentCompliance` (row-level department filter)
5. Execution plan captured with `SET SHOWPLAN_TEXT` before/after index optimization

**Demonstrates:** Dynamic SQL, dynamic cursor, row-level view security, indexing impact

### 4.5 Business Rules

#### Insert / Update / Delete Conditions

| Rule | Enforcement |
|------|-------------|
| Enrollment date cannot be in the future | Trigger + procedure validation |
| Exam score must be 0–100 | CHECK constraint + trigger |
| Cannot enroll same employee in same course twice while Pending/Completed | UNIQUE constraint + trigger |
| Certification expiry = exam date + course validity months | Computed in procedure on pass |
| Only HR_Admin may DELETE enrollment records | DENY DELETE to Clerk and Employee roles |
| Review decision requires Manager or Admin role | Procedure permission check |
| Queue status must follow: Pending Review → Notified → Resolved | Trigger on UPDATE |

#### Access Permissions and Restrictions

| Rule | Enforcement |
|------|-------------|
| Employee_Client sees only own records | View `vw_EmployeeSelfService` with `WHERE BusinessEmployeeID = USER_ID()` predicate |
| Manager sees only their department | View `vw_ManagerDepartmentCompliance` filtered by department |
| Clerk cannot access review approval procedures | DENY EXECUTE on `usp_ProcessCertificationReview` |
| Admin-only role management | GRANT ALTER ANY ROLE only to HR_Admin |

#### Data Consistency Requirements

| Rule | Enforcement |
|------|-------------|
| FK integrity between all child tables | FOREIGN KEY constraints with appropriate ON DELETE rules |
| Cascading status update when review = Re-Enroll | Transaction in `usp_ProcessCertificationReview` |
| Date/time validation on exam vs enrollment | Trigger `trg_TrainingRequests_ValidateEnrollment` |
| Prevent orphaned queue records | FK + INSTEAD OF DELETE trigger on `TrainingRequests` |

### 4.6 Justification of T-SQL Feature Usage

| Feature | Business Justification |
|---------|------------------------|
| **Triggers** | Automatically enforce enrollment rules, audit status changes, and prevent invalid queue updates without relying on application layer |
| **Views** | Abstract complex joins for reports; enforce row-level security so Employees and Managers see only authorized rows |
| **Role-Based Security** | HR data is sensitive — roles mirror real org structure (Admin, Manager, Clerk, Employee) |
| **Indexing** | Compliance reports scan large enrollment history — indexes on status, department, and expiry dates reduce table scans |
| **Procedural Logic** | Enrollment, review, and reporting require parameterized, validated, reusable operations with transaction safety |
| **Dynamic SQL** | Managers need flexible compliance filters (by department, course, date range) without hard-coding dozens of reports |
| **Cursors** | Expiry notification and department iteration require row-by-row processing where set-based logic is demonstrated alongside cursor alternatives |

---

## 5. Technical Environment

| Component | Specification |
|-----------|---------------|
| Database Server | Microsoft SQL Server 2016 (vApp) |
| Management Tool | SQL Server Management Studio (SSMS) |
| Version Control | Private GitHub repository with commit history |
| Script Format | Text-based `.sql` files only |
| **Prohibited** | GUI designers, ORMs, visual tools, frontend applications |

---

## 6. Functional Requirements

All objects written in T-SQL, stored in separate `.sql` files, organized in the repository structure defined in Section 12.

### 6.1 Schema Design

| Requirement | HRTrainingOps Implementation |
|-------------|------------------------------|
| Minimum 6 normalized tables (3NF+) | 7 tables — see Section 4.1 |
| Primary keys | IDENTITY PK on all tables |
| Foreign keys | All inter-table relationships explicitly declared |
| Default values | `CreatedDate`, `QueuedDate`, `RequestStatus` defaults |
| Data type constraints | CHECK on scores, dates, status enums |
| Indexing considered at design | Index plan in `optimization/indexes.sql` |

#### Table Definitions

**`HRTrainingOps.TrainingCourse`**

| Column | Type | Constraints |
|--------|------|-------------|
| CourseCode | NVARCHAR(10) | PK |
| CourseName | NVARCHAR(100) | NOT NULL |
| ValidityMonths | INT | NOT NULL, CHECK > 0 |
| IsMandatory | BIT | DEFAULT 0 |
| CreatedDate | DATETIME2 | DEFAULT GETDATE() |

**`HRTrainingOps.TrainingRequests`**

| Column | Type | Constraints |
|--------|------|-------------|
| TrainingRequestID | INT IDENTITY | PK (clustered) |
| BusinessEmployeeID | INT | NOT NULL |
| CourseCode | NVARCHAR(10) | FK → TrainingCourse |
| EnrollmentDate | DATE | NOT NULL |
| ExamDate | DATE | NULL |
| Score | DECIMAL(5,2) | CHECK 0–100 |
| CertificationExpiryDate | DATE | NULL |
| RequestStatus | NVARCHAR(20) | DEFAULT 'Pending' |
| DepartmentID | INT | NULL |
| CreatedDate | DATETIME2 | DEFAULT GETDATE() |

**`HRTrainingOps.DepartmentTrainingRequirement`**

| Column | Type | Constraints |
|--------|------|-------------|
| RequirementID | INT IDENTITY | PK |
| DepartmentID | INT | NOT NULL |
| CourseCode | NVARCHAR(10) | FK → TrainingCourse |
| IsRequired | BIT | DEFAULT 1 |
| UNIQUE | | (DepartmentID, CourseCode) |

**`HRTrainingOps.ExpiredCertificationQueue`**, **`CertificationReleaseReview`**, **`NotificationLog`**, **`ErrorLog`** — as defined in prior design sections with full FK declarations.

### 6.2 Procedural Logic Requirements

| Object Type | Required | Planned | Notes |
|-------------|----------|---------|-------|
| Stored Procedures | ≥ 5 | **6** | Includes 1 dynamic SQL procedure |
| User-Defined Functions | ≥ 2 | **2** | 1 scalar + 1 inline TVF |
| Views | ≥ 3 | **4** | Abstraction + role-specific row filtering |
| Triggers | ≥ 3 | **3** | AFTER triggers for DML control |
| Cursors | ≥ 2 | **2** | 1 static + 1 dynamic |

#### Stored Procedures

| Procedure | Owner | Purpose |
|-----------|-------|---------|
| `usp_EnrollEmployeeInCourse` | Parth | Enroll employee with transaction + validation |
| `usp_GetTrainingRequests` | Parth | Parameterized search by status/course |
| `usp_ProcessCertificationReview` | Parth | Manager approval workflow with transaction |
| `usp_RunComplianceReport` | Dhruv | **Dynamic SQL** — filter by dept/course/date |
| `usp_BatchUpdateExpiredCertifications` | Dhruv | Batch queue population with transaction |
| `usp_GetDepartmentTrainingStats` | Dhruv | Department statistics report |

#### User-Defined Functions

| Function | Owner | Type |
|----------|-------|------|
| `fn_TrainingScoreClass` | Parth | Scalar — Pass / Conditional / Fail |
| `fn_GetEmployeeTrainingData` | Parth | Inline TVF — employee training rows |

#### Views

| View | Owner | Purpose |
|------|-------|---------|
| `vEmployeeTrainingSummary` | Sahil | Joined summary for reporting |
| `vw_PendingCertifications` | Sahil | Pending exams and renewals |
| `vw_ManagerDepartmentCompliance` | Sahil | Row-level dept filter for Managers |
| `vw_EmployeeSelfService` | Sahil | Employee sees own records only |

#### Triggers

| Trigger | Owner | Type | Purpose |
|---------|-------|------|---------|
| `trg_TrainingRequests_ValidateEnrollment` | Parth | AFTER INSERT, UPDATE | Date/score/duplicate validation |
| `trg_TrainingRequests_AuditStatusChange` | Parth | AFTER UPDATE | Audit status changes to ErrorLog |
| `trg_ExpiredQueue_StatusTransition` | Parth | AFTER UPDATE | Enforce valid queue status transitions |

#### Cursors

| Cursor Script | Owner | Type |
|---------------|-------|------|
| `expired_certification_review_cursor.sql` | Dhruv | **Static** — process expiry queue |
| `usp_DynamicDepartmentNotification` | Dhruv | **Dynamic** — iterate departments for notifications |

All procedures and functions include **parameterization, validation, and flow control**.

### 6.3 Security & Access Control

| Requirement | Implementation |
|-------------|----------------|
| Minimum 3 roles | **4 roles:** HR_Admin, HR_Manager, Training_Clerk, Employee_Client |
| GRANT / REVOKE / DENY | `security/permissions.sql` |
| Row-level access filtering | `vw_EmployeeSelfService`, `vw_ManagerDepartmentCompliance` |
| Permission test | `security/test_cases.sql` — simulates each role |

**Permission Summary:**

| Object | HR_Admin | HR_Manager | Training_Clerk | Employee_Client |
|--------|----------|------------|----------------|-----------------|
| All tables | FULL | SELECT + limited UPDATE | INSERT/UPDATE (no DELETE) | SELECT via view only |
| `usp_ProcessCertificationReview` | EXECUTE | EXECUTE | **DENY** | **DENY** |
| `usp_EnrollEmployeeInCourse` | EXECUTE | EXECUTE | EXECUTE | **DENY** |
| Compliance views | GRANT | GRANT | REVOKE | GRANT (self only) |

### 6.4 Transaction Management

All INSERT/UPDATE/DELETE operations in procedures include:

| Feature | Where Applied |
|---------|---------------|
| `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` | `usp_EnrollEmployeeInCourse`, `usp_ProcessCertificationReview`, `usp_BatchUpdateExpiredCertifications` |
| `TRY...CATCH` | All 6 stored procedures |
| Lock awareness | `SET TRANSACTION ISOLATION LEVEL READ COMMITTED` documented in procedures |
| Deadlock / isolation simulation | `test_cases.sql` — concurrent enrollment test with isolation level comparison |

### 6.5 Indexing & Performance

| Index Type | Required | Implementation |
|------------|----------|----------------|
| Clustered | 1 | PK clustered on `TrainingRequests.TrainingRequestID` |
| Non-clustered | 1 | `IX_ExpiredQueue_EmployeeExpiry` on `(BusinessEmployeeID, ExpiryDate)` |
| Filtered / INCLUDE | 1 | `IX_TrainingRequests_Pending` filtered `WHERE RequestStatus = 'Pending'` INCLUDE `(CourseCode, EnrollmentDate)` |

**Performance Analysis:**

- Capture execution plans using `SET SHOWPLAN_TEXT ON` before and after indexes
- Document impact in `optimization/index_analysis_notes.md`
- Compare logical reads for compliance report query pre/post indexing

---

## 7. Project Phases

### Phase I — Schema Planning & Setup

**Owner Lead:** Sahil Maniya (Schema Designer)

| Activity | Output |
|----------|--------|
| Define business case and roles | This document — Sections 3–4 |
| Create full ERD | `diagrams/hrtrainingops_erd.pdf` |
| Normalize and script table creation | `schema/` folder — 7 CREATE TABLE scripts |
| Add constraints and relational integrity | PKs, FKs, CHECK, UNIQUE in schema scripts |
| Initialize GitHub repository | Private repo with README |

**Expected Output:**

- `schema/` — all CREATE TABLE scripts
- ERD (PDF + draw.io source)
- `README.md` — project overview and team members

---

### Phase II — Logic & Security Implementation

**Owner Lead:** Parth Patel (Logic Developer)

| Activity | Output |
|----------|--------|
| Stored procedures, triggers, functions, views | `procedures/`, `functions/`, `views/`, `triggers/` |
| Security and permissions | `security/permissions.sql` |
| Test scripts simulating user workflows | `security/test_cases.sql` |
| Dynamic SQL and cursor procedures | `usp_RunComplianceReport`, dynamic cursor script |

**Expected Output:**

- `procedures/`, `functions/`, `views/`, `triggers/` folders populated
- `security/permissions.sql` and `security/test_cases.sql`
- Structured GitHub commit history (minimum 5 commits per member)

---

### Phase III — Optimization & Final Integration

**Owner Lead:** Dhruv (Security & Optimization Lead)

| Activity | Output |
|----------|--------|
| Create indexes and compare performance | `optimization/indexes.sql` + analysis notes |
| Finalize modular script organization | All folders complete |
| Validate schema with sample data | `test_data.sql` |
| Permission testing | Run `security/test_cases.sql` |
| Full deployment script | `final_script.sql` |

**Expected Output:**

- `optimization/` — index scripts and performance notes
- `test_data.sql` — full sample data load
- `final_script.sql` — master deployment from clean environment
- Updated README and summary log

---

## 8. Repository Structure

```
HRTrainingOps/
│
├── schema/                         ← Phase I (Sahil)
│   ├── 01_create_schema.sql
│   ├── 02_training_course.sql
│   ├── 03_training_requests.sql
│   ├── 04_department_training_requirement.sql
│   ├── 05_expired_certification_queue.sql
│   ├── 06_certification_release_review.sql
│   ├── 07_notification_log.sql
│   └── 08_error_log.sql
│
├── views/                          ← Phase II (Sahil)
├── procedures/                     ← Phase II (Parth + Dhruv)
├── functions/                      ← Phase II (Parth)
├── triggers/                       ← Phase II (Parth)
├── security/                       ← Phase II–III (Dhruv)
│   ├── permissions.sql
│   └── test_cases.sql
├── optimization/                   ← Phase III (Dhruv)
│   ├── indexes.sql
│   └── index_analysis_notes.md
│
├── test_data.sql                   ← Phase III
├── final_script.sql                ← Phase III (master deploy)
│
├── diagrams/
│   ├── hrtrainingops_erd.pdf
│   └── hrtrainingops_erd.drawio
│
├── screenshots/
│   ├── Sahil/
│   ├── Parth/
│   └── Dhruv/
│
├── README.md
└── PROJECT_PROPOSAL_HRTrainingOps.md
```

---

## 9. Team Composition & Roles

### 9.1 Team Members

| Name | Student No. | GitHub Username | Assigned Role |
|------|-------------|-----------------|---------------|
| Sahil Maniya | | | **Schema Designer** — data modeling, tables, normalization, views, ERD, final integration |
| Parth Patel | | | **Logic Developer** — stored procedures, functions, triggers, transactions, error handling |
| Dhruv | | | **Security & Optimization Lead** — roles/permissions, indexes, performance analysis, test scripts, cursors |

### 9.2 Responsibility Matrix

| Area | Sahil | Parth | Dhruv |
|------|:-----:|:-----:|:-----:|
| Schema / ERD | ✓ Lead | Support | Support |
| Stored Procedures | Support | ✓ Lead | ✓ (2 procs) |
| Functions | | ✓ Lead | |
| Views | ✓ Lead | | |
| Triggers | | ✓ Lead | |
| Cursors | | | ✓ Lead |
| Security / Roles | | Support | ✓ Lead |
| Indexing / Optimization | | | ✓ Lead |
| `final_script.sql` | ✓ Lead | Support | Support |
| Demo & Q&A | ✓ | ✓ | ✓ |

### 9.3 Collaboration Rules

- Each script has one primary owner; all members must understand every component for demo Q&A
- Workload distributed evenly across Phase I, II, and III
- Minimum **5 meaningful GitHub commits per student**
- All members participate in final live demonstration

---

## 10. Final Presentation

### Phase 1 — Live Demonstration & Technical Validation

Deploy from clean SQL Server 2016 environment using `final_script.sql`, then run `test_cases.sql` demonstrating:

| Component | Script / Object |
|-----------|-----------------|
| Stored procedures (all types) | 6 procedures including dynamic SQL |
| Triggers | 3 DML triggers |
| Views | 4 views including row-level security |
| User-defined functions | Scalar + inline TVF |
| Cursors | 1 static + 1 dynamic |
| Transaction control | BEGIN / COMMIT / ROLLBACK in enrollment and review |
| Role-based access | GRANT / REVOKE / DENY via `security/test_cases.sql` |

All output visible in SSMS result windows. Scripts execute **without modification**.

### Phase 2 — Component-Level Explanation & Q&A

Each member responds to instructor prompts on:

- Business logic implementation
- Constraint handling and data integrity
- Security model and user roles
- Optimization techniques and execution plan decisions
- Justification for triggers, procedures, views, and cursor vs set-based alternatives

**No presentation software.** Only SSMS output and script references permitted.

---

## 11. Evaluation Criteria

| Component | Weight |
|-----------|--------|
| Phase I — Schema Design & ERD | 7% |
| Phase II — Logic, Security, Transactions | 7% |
| Phase III — Optimization & Integration | 6% |
| Final Demo & Presentation | 10% |
| **Total Course Contribution** | **30%** |

---

## 12. Submission Guidelines

### GitHub Repository

- One **private** repository per group
- Clear folder names: `schema/`, `views/`, `procedures/`, `functions/`, `triggers/`, `security/`, `optimization/`
- Minimum **5 meaningful commits per student**

### README.md Must Include

- Business case summary
- Schema overview (7 entities)
- Team members, student numbers, GitHub usernames
- Assigned roles and contribution summary
- Instructions to run `final_script.sql` and `test_cases.sql`

### Blackboard Submission

- GitHub repository link
- ERD in **PDF format only** (`diagrams/hrtrainingops_erd.pdf`)

### Submission Checklist

- [ ] 7 normalized tables in `schema/` with PKs, FKs, constraints
- [ ] 6 stored procedures (1 with dynamic SQL)
- [ ] 2 user-defined functions
- [ ] 4 views (including row-level security views)
- [ ] 3 triggers
- [ ] 2 cursors (1 static, 1 dynamic)
- [ ] 4 database roles with GRANT / REVOKE / DENY
- [ ] 3 indexes (clustered, non-clustered, filtered INCLUDE)
- [ ] Transaction + TRY/CATCH in all DML procedures
- [ ] `test_data.sql` and `final_script.sql`
- [ ] `security/test_cases.sql` permission tests
- [ ] Execution plan analysis in `optimization/`
- [ ] README complete with team roles
- [ ] ERD PDF uploaded to Blackboard
- [ ] GitHub link submitted to Blackboard
- [ ] All 3 members ready for live demo and Q&A

---

## 13. Academic Integrity

All code must be authored by our group. Every member must be able to explain all components during review. Use of unauthorized AI code generation, copy-paste without understanding, or peer replication is prohibited and addressed under **Humber's Academic Integrity Policy**.

---

## 14. Data Mapping (AdventureWorks Integration)

| HRTrainingOps Object | AdventureWorks Source | Mapping Logic |
|----------------------|----------------------|---------------|
| `TrainingRequests.BusinessEmployeeID` | `HumanResources.Employee.BusinessEntityID` | Direct reference |
| Employee name (views/reports) | `Person.Person` | JOIN on `BusinessEntityID` |
| `DepartmentTrainingRequirement.DepartmentID` | `HumanResources.Department` | Department reference |
| Job title | `HumanResources.Employee.JobTitle` | Reporting attribute |
| Active employees | `HumanResources.Employee.CurrentFlag = 1` | Seed filter |
| Enrollment / exam dates | Derived seed data | Realistic date ranges |
| Scores | Derived seed data | Mixed Pass / Fail outcomes |

---

## 15. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Schema not complete before Phase II | Sahil completes Phase I before logic development begins |
| Security tests fail | Run `test_cases.sql` after every permission change |
| Performance targets not met | Capture SHOWPLAN before/after indexes in Phase III |
| Uneven commit history | Each member commits their owned scripts with meaningful messages |
| Demo script failure | Test `final_script.sql` on clean vApp environment before presentation |

---

## 16. Approval

| Role | Name | Student No. | Signature | Date |
|------|------|-------------|-----------|------|
| Schema Designer | Sahil Maniya | | _________________ | ________ |
| Logic Developer | Parth Patel | | _________________ | ________ |
| Security & Optimization Lead | Dhruv | | _________________ | ________ |
| Instructor | | | _________________ | ________ |

---

*Course Project Specification v2.0 — Employee Training & Certification Tracker (HRTrainingOps)*
