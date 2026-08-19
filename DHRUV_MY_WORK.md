# My Part — Security & Optimization Lead (Dhruv Patel)

**Project:** HRTrainingOps — Employee Training & Certification Tracker
**My role:** Security & Optimization Lead
**What I owned:** database roles & permissions, 2 of the 6 stored procedures (1 with dynamic SQL), 1 of the 2 cursors (the dynamic one) plus co-ownership of the static one, all indexing/performance work, and the permission test suite.

This is my personal presentation script — what I built, how, and why — for the live demo and Q&A.

---

## 1. Where my work sits in the system

| Area | My files |
|------|----------|
| Security | `security/permissions.sql`, `security/test_cases.sql` |
| Stored procedures | `procedures/usp_RunComplianceReport.sql`, `procedures/usp_BatchUpdateExpiredCertifications.sql`, `procedures/usp_GetDepartmentTrainingStats.sql` |
| Cursors | `procedures/expired_certification_review_cursor.sql` (static), `procedures/usp_DynamicDepartmentNotification.sql` (dynamic) |
| Optimization | `optimization/indexes.sql`, `optimization/index_performance_compare.sql`, `optimization/index_analysis_notes.md` |
| Evidence | `Screenshot/Dhruv/` |

I own Phase III end-to-end (optimization & final integration lead) and contributed 2 of Parth's Phase II procedure slots plus one cursor, since the spec split cursors 1 static / 1 dynamic and procedures 6 total across the team.

---

## 2. Security — 4 roles, GRANT/REVOKE/DENY (`security/permissions.sql`)

**What I built:** 4 SQL Server logins + database users + 4 database roles, with role membership and object-level permissions applied per role.

| Login | Role | Purpose |
|-------|------|---------|
| `HRTO_Admin` | `HR_Admin` | Full schema control |
| `HRTO_Manager` | `HR_Manager` | Department oversight, reviews, compliance |
| `HRTO_Mgr_7` | `HR_Manager` | Second manager scoped to Department 7 — proves the row-level view filters by *caller*, not by a hardcoded value |
| `HRTO_Clerk` | `Training_Clerk` | Data entry — enroll/update, no delete, no review |
| `HRTO_Emp_288` | `Employee_Client` | Self-service, one employee's own data only |

**How I implemented it:**
- Roles are created with `CREATE ROLE ... AUTHORIZATION dbo` and populated with `ALTER ROLE ... ADD MEMBER`, so permissions are managed at the role level, not per-login — standard practice, and it's what lets me add `HRTO_Mgr_7` later without re-granting anything.
- Every `CREATE LOGIN` / `CREATE USER` / `CREATE ROLE` is wrapped in `IF NOT EXISTS`, so the script is **idempotent** — it can be re-run safely as part of `final_script.sql` without erroring on a second deploy.
- Permissions are layered: broad `GRANT` at the schema level for `HR_Admin` (`GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::HRTrainingOps`), then explicit object-level `GRANT`s for `HR_Manager` and `Training_Clerk`, then explicit `DENY`s to close specific gaps a broader grant would otherwise leave open.
- **DENY beats GRANT** in SQL Server's permission model, and I use that deliberately — e.g. `Training_Clerk` gets `INSERT`/`UPDATE` on `TrainingRequests` for enrollment work, but I `DENY DELETE` on it and `DENY EXECUTE` on `usp_ProcessCertificationReview` so a clerk can never bypass the review workflow even indirectly.
- `Employee_Client` gets **no direct table access at all** — only `SELECT` on `vw_EmployeeSelfService` — so "employees see only their own record" is enforced by *what they're allowed to touch*, not by a `WHERE` clause an application might forget to add.
- I also grant the minimum needed read access into AdventureWorks base tables (`HumanResources.Employee`, `HumanResources.Department`, `Person.Person`) to the roles whose procedures/views join into them — otherwise `EXECUTE AS USER` impersonation in the procedures would fail with a permission error even though the *procedure* itself is grantable.

**Business rules this enforces (from the spec):**
- Only `HR_Admin` may `DELETE` enrollment records.
- Review decisions require Manager or Admin (Clerk is denied `usp_ProcessCertificationReview`).
- Employees see only their own records (no base-table grant, view-only).
- Admin-only role management (`GRANT ALTER ANY ROLE` scoped to `HRTO_Admin` alone).

---

## 3. Permission test suite (`security/test_cases.sql`)

I didn't just write the grants — I proved them. The last section of `test_cases.sql` uses `EXECUTE AS USER = '<login>'` / `REVERT` to actually **become** each role and attempt both allowed and forbidden actions:

| Test | Principal | Expected result |
|------|-----------|------------------|
| 5a | `HRTO_Clerk` | Enrollment **succeeds** |
| 5b | `HRTO_Clerk` | `usp_ProcessCertificationReview` **fails** (DENY) |
| 5c | `HRTO_Emp_288` | Self-service view works; direct `SELECT` on `TrainingRequests` **fails** |
| 5d | `HRTO_Manager` | Compliance report + manager view **succeed** |
| 5e | `HRTO_Clerk` | `DELETE` on `TrainingRequests` **fails**, even with zero matching rows (DENY fires before the row filter is evaluated) |

Each negative test is wrapped in `TRY/CATCH` and treats the **caught error as the pass condition** — if a forbidden action *doesn't* throw, the script prints an explicit `ERROR:` line instead of silently passing. I also made sure every `EXECUTE AS` path calls `REVERT` even inside the `CATCH` block, so a failed test never leaves the session impersonating another principal for the rest of the script.

This section also seeds/exercises all three business workflows end-to-end (enrollment → batch expiry → cursor notify → manager review → compliance report), so it doubles as the functional smoke test for the whole system, not just my security slice.

---

## 4. Indexing & performance (`optimization/`)

**What I built:** the required index set (1 clustered — already present from Phase I schema, 1 non-clustered, 1 filtered+INCLUDE) plus two supporting indexes for reporting, and a before/after measurement script.

| Index | Type | Definition | Why |
|-------|------|------------|-----|
| `PK_TrainingRequests` | Clustered (Phase I) | `TrainingRequestID` | Surrogate identity PK — natural clustering key for an append-heavy table; every FK lookup goes through this ID |
| `IX_ExpiredQueue_EmployeeExpiry` | Non-clustered | `(BusinessEmployeeID, ExpiryDate)` INCLUDE `CourseCode, QueueStatus, DaysOverdue` | Workflow 2 (batch expiry + cursor) scans the queue by employee and age-of-expiry; the INCLUDE columns make it a **covering index** so the engine doesn't need a key lookup back to the base table |
| `IX_TrainingRequests_Pending` | Filtered + INCLUDE | `EnrollmentDate` INCLUDE `CourseCode, BusinessEmployeeID, DepartmentID` WHERE `RequestStatus = 'Pending'` | Pending enrollments are the "hot" subset clerks/managers query constantly; a filtered index only indexes that slice, so it's smaller and cheaper to maintain than indexing the whole (mostly historical) table |
| `IX_TrainingRequests_DeptStatus` | Supporting NCI | `(DepartmentID, RequestStatus)` INCLUDE reporting columns | Backs the compliance report and department stats query (my `usp_RunComplianceReport` / `usp_GetDepartmentTrainingStats`) |
| `IX_TrainingRequests_Expiry` | Supporting NCI | `(CertificationExpiryDate, RequestStatus)` INCLUDE keys | Backs my batch-expiry procedure's scan for newly-expired rows |

**How I proved impact:** `optimization/index_performance_compare.sql` runs the same 3 representative queries with `SET STATISTICS IO/TIME ON`, captures `sys.dm_db_index_usage_stats` to show actual seeks vs. scans, and captures `SET SHOWPLAN_TEXT ON` output for the pending-enrollments query. The intent — documented in `index_analysis_notes.md` — is to run this **before** `indexes.sql` (baseline, expect Clustered Index Scan) and **after** (expect Index Seek on the new filtered index), and record logical reads pre/post as evidence.

I deliberately chose queries whose `WHERE`/join shape lines up 1:1 with each index, so the plan change (Scan → Seek) is unambiguous in the demo even on the small sample data set, where raw logical-read counts alone might look unconvincing.

---

## 5. My stored procedures

### `usp_RunComplianceReport` — the dynamic SQL requirement (Workflow 3)

- Builds the `SELECT` and its `WHERE` clause as a string, appending predicate fragments only for the filters the caller actually supplied (`@DepartmentName`, `@CourseCode`, `@FromDate`, `@ToDate`).
- **Values are never concatenated into the string** — only column/predicate *shape* is dynamic. Values go through `sp_executesql`'s parameter list (`@pDepartmentName`, `@pCourseCode`, ...), which is what prevents SQL injection and also lets the plan cache reuse compiled plans across calls with different filter values.
- Computes a `ComplianceFlag` (`Compliant` / `In Progress` / `Non-Compliant` / `Review`) in a `CASE` expression so the report is decision-ready output, not just raw rows.
- Wrapped in `TRY/CATCH`; on failure it logs `ERROR_NUMBER/MESSAGE/PROCEDURE/LINE` into `ErrorLog` before re-`THROW`ing, so failures are both surfaced to the caller and auditable afterward.

### `usp_BatchUpdateExpiredCertifications` — Workflow 2, step 1

- Two-step transaction: first flips `Completed` rows whose `CertificationExpiryDate` has passed to `Expired`, then inserts the newly-expired (and any previously `Failed`) rows into `ExpiredCertificationQueue` — guarded by `NOT EXISTS` so re-running the batch never double-queues the same request.
- `SET XACT_ABORT ON` + explicit `BEGIN/COMMIT/ROLLBACK TRANSACTION` in `TRY/CATCH`: if either the `UPDATE` or the `INSERT` fails, the whole batch rolls back atomically rather than leaving requests marked `Expired` without a matching queue row.
- `@RowsQueued OUTPUT` reports back how many rows were actually queued, which `test_cases.sql` and the presentation both use as the visible proof-of-work.

### `usp_GetDepartmentTrainingStats` — department reporting

- Single aggregate query (`COUNT`/`SUM(CASE...)`/`AVG`) per department: total enrollments, pending/completed/failed/expired counts, average score, and currently-valid certification count.
- `LEFT JOIN` from `Department` so departments with zero enrollments still appear in the report (with zero counts) instead of disappearing — important for a compliance report where "no data" is itself a finding.
- Optional `@DepartmentID` parameter with an `IS NULL OR` guard, so the same procedure serves both "all departments" and "one department" without branching logic.

---

## 6. My cursors

### Static cursor — `usp_ProcessExpiryQueueWithCursor` (`expired_certification_review_cursor.sql`)

- `DECLARE ... CURSOR STATIC LOCAL` over queue rows in `Pending Review` status, ordered by `DaysOverdue DESC` (most-overdue first).
- Row-by-row: inserts a `NotificationLog` entry with a formatted message, then flips that one queue row to `Notified`.
- I used a **static** cursor here specifically because the demo requires a stable, order-guaranteed row-by-row walk that doesn't need to see concurrent writes mid-iteration — a plain snapshot is both correct and cheaper than a scrollable/dynamic cursor for this use case.
- Whole loop runs inside one transaction with `XACT_ABORT ON`; the `CATCH` block checks `CURSOR_STATUS` before closing/deallocating so cleanup never errors on a cursor that was never opened or already closed.

### Dynamic cursor — `usp_DynamicDepartmentNotification` (Workflow 3)

- First stages "which departments have employees missing a required course" into a `#DeptGaps` temp table (a set-based query — `INNER JOIN` + `NOT EXISTS` + `GROUP BY/HAVING`), then walks *that* staged result with a `CURSOR DYNAMIC LOCAL`.
- I explicitly chose `DYNAMIC` (not `STATIC`) to satisfy the spec's requirement to demonstrate the SQL Server dynamic cursor type — it reflects underlying changes during iteration, which is the textbook distinguishing feature I can speak to in Q&A even though this particular loop doesn't mutate `#DeptGaps` mid-walk.
- Also takes an optional `@DepartmentName` filter, so it can run for one department or all of them — reused directly by `usp_RunComplianceReport`'s companion workflow test.

**Why set-based staging + cursor, not a straight set-based `INSERT...SELECT`:** the spec asks me to demonstrate cursor usage *and* contrast it with the set-based alternative during Q&A — I can point out that the notification-generation step is intentionally cursor-based per requirement, while the *detection* of gaps (the harder part) is already set-based, showing I know which one is normally the right tool.

---

## 7. How my pieces fit the 3 required workflows

| Workflow | My contribution |
|----------|------------------|
| 1 — Enrollment | Security: Clerk/Admin are the only roles that can call `usp_EnrollEmployeeInCourse`; proven in `test_cases.sql` §1 and §5a |
| 2 — Expired Certification Review | `usp_BatchUpdateExpiredCertifications` (populate queue) → `usp_ProcessExpiryQueueWithCursor` (static cursor, notify) → Manager reviews (permission-gated by my DENY on Clerk) |
| 3 — Compliance Audit Report | `usp_RunComplianceReport` (dynamic SQL) + `usp_DynamicDepartmentNotification` (dynamic cursor) + indexes backing both, + `vw_ManagerDepartmentCompliance` row-level access controlled by my grants |

---

## 8. Demo run order (what I'll show live)

1. `security/permissions.sql` — create roles/logins (idempotent, safe to re-run)
2. `optimization/index_performance_compare.sql` — **baseline** STATISTICS IO (before indexes)
3. `optimization/indexes.sql` — create the index set
4. `optimization/index_performance_compare.sql` — **post-index** STATISTICS IO + SHOWPLAN — show Scan → Seek
5. `security/test_cases.sql` — full run: seeds data, exercises all 3 workflows, then proves each role's permissions with `EXECUTE AS`

---

## 9. Anticipated Q&A — points I need to be able to explain cold

- **Why DENY instead of just not granting?** Not granting only blocks access if no *other* grant (direct or via another role/group) exists. `DENY` overrides any grant unconditionally — safer when a principal could pick up permissions from more than one source.
- **Why a filtered index instead of indexing the whole table?** Smaller index → less disk, faster maintenance on every INSERT/UPDATE, and it's a covering index for exactly the query shape (pending-status lookups) that runs most often.
- **Static vs. dynamic cursor — why does it matter?** Static takes a snapshot at `OPEN` time (cheaper, stable order); dynamic re-reflects underlying table changes as you fetch (more overhead, needed only when the loop itself may cause or must observe concurrent changes). I used static for the queue walk (no concurrent-change requirement) and dynamic for the department-gap walk (spec requirement to demonstrate the type).
- **Why `sp_executesql` and not `EXEC(@sql)`?** Parameterization prevents SQL injection and allows plan-cache reuse; string-only `EXEC` would force a fresh compile (and be injectable) for every distinct filter combination.
- **What happens if `usp_BatchUpdateExpiredCertifications` fails halfway?** `XACT_ABORT ON` + `TRY/CATCH` with `ROLLBACK` means the `UPDATE` and the `INSERT` either both apply or neither does — no request is left marked `Expired` without a corresponding queue entry.
