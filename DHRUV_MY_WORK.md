# My Part — Security & Optimization Lead (Dhruv Patel)

**Project:** HRTrainingOps — Employee Training & Certification Tracker
**My role:** Security & Optimization Lead
**What I owned:** database roles & permissions, 2 of the 6 stored procedures (1 with dynamic SQL), 1 of the 2 cursors (the dynamic one) plus co-ownership of the static one, all indexing/performance work, and the permission test suite.

Presentation script — code snippet, then what it does and why, for each piece I built.

| Area | My files |
|------|----------|
| Security | `security/permissions.sql`, `security/test_cases.sql` |
| Stored procedures | `procedures/usp_RunComplianceReport.sql`, `procedures/usp_BatchUpdateExpiredCertifications.sql`, `procedures/usp_GetDepartmentTrainingStats.sql` |
| Cursors | `procedures/expired_certification_review_cursor.sql` (static), `procedures/usp_DynamicDepartmentNotification.sql` (dynamic) |
| Optimization | `optimization/indexes.sql`, `optimization/index_performance_compare.sql`, `optimization/index_analysis_notes.md` |

---

## 1. Security — roles, GRANT/REVOKE/DENY

**Idempotent role setup** (`security/permissions.sql`):

```sql
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'HR_Manager' AND type = N'R')
    CREATE ROLE HR_Manager AUTHORIZATION dbo;
GO

ALTER ROLE HR_Manager ADD MEMBER HRTO_Manager;
ALTER ROLE HR_Manager ADD MEMBER HRTO_Mgr_7;   -- second manager, scoped to Dept 7
```
- Every `CREATE` guarded by `IF NOT EXISTS` — script re-runs safely inside `final_script.sql`.
- Two manager logins prove the row-level view filters by *caller*, not a hardcoded value.

**Layered GRANT, then explicit DENY to close gaps:**

```sql
GRANT SELECT, INSERT, UPDATE ON HRTrainingOps.TrainingRequests TO Training_Clerk;
...
DENY DELETE ON HRTrainingOps.TrainingRequests TO Training_Clerk;
DENY EXECUTE ON HRTrainingOps.usp_ProcessCertificationReview TO Training_Clerk;
```
- `Training_Clerk` needs INSERT/UPDATE to do enrollment work, but `DENY` closes the two doors a broad grant would otherwise leave open — DELETE and the review procedure.
- `DENY` beats any `GRANT` a principal might pick up from another role, so it's the safer tool here, not just "don't grant."

**Employee self-service — no base table access at all:**

```sql
GRANT SELECT ON HRTrainingOps.vw_EmployeeSelfService TO Employee_Client;
DENY SELECT ON HRTrainingOps.TrainingRequests TO Employee_Client;
```
- "Employees see only their own record" is enforced by *what they can touch*, not a `WHERE` clause an app could forget.

---

## 2. Permission test suite (`security/test_cases.sql`)

**Proving a role can do what it should:**

```sql
EXECUTE AS USER = N'HRTO_Clerk';
EXEC HRTrainingOps.usp_EnrollEmployeeInCourse
    @BusinessEmployeeID = @ClerkEmp, @CourseCode = N'HRCOMP02', ...;
PRINT 'Clerk enrollment OK. RequestID=' + CAST(@ClerkReq AS NVARCHAR(20));
REVERT;
```

**Proving a role can't do what it shouldn't — the caught error IS the pass:**

```sql
BEGIN TRY
    EXECUTE AS USER = N'HRTO_Clerk';
    DELETE FROM HRTrainingOps.TrainingRequests WHERE TrainingRequestID = -1;
    PRINT 'ERROR: Clerk DELETE should be denied.';   -- would mean the test FAILED
    REVERT;
END TRY
BEGIN CATCH
    PRINT 'Expected DENY DELETE for Clerk: ' + ERROR_MESSAGE();
    BEGIN TRY REVERT; END TRY BEGIN CATCH END CATCH;   -- REVERT even if the block errored
END CATCH;
```
- `DENY` fires even with zero matching rows (`TrainingRequestID = -1`) — it blocks at the permission check, before row evaluation.
- `REVERT` is called in both `TRY` and `CATCH` so a failed test never leaves the session impersonating another principal.
- Five of these (5a–5e) cover: Clerk enrolls ✓, Clerk denied review ✗, Employee self-service only, Manager runs reports ✓, Clerk denied DELETE ✗.

---

## 3. Indexing (`optimization/indexes.sql`)

**Filtered + INCLUDE index — the one I'll get asked about most:**

```sql
CREATE NONCLUSTERED INDEX IX_TrainingRequests_Pending
    ON HRTrainingOps.TrainingRequests (EnrollmentDate)
    INCLUDE (CourseCode, BusinessEmployeeID, DepartmentID)
    WHERE RequestStatus = N'Pending';
```
- Pending enrollments are the hot subset clerks/managers query constantly — indexing only that slice keeps it small and cheap to maintain.
- `INCLUDE` columns make it a **covering index** for that query shape — no key lookup back to the base table.

**Covering index for the expiry-queue workflow:**

```sql
CREATE NONCLUSTERED INDEX IX_ExpiredQueue_EmployeeExpiry
    ON HRTrainingOps.ExpiredCertificationQueue (BusinessEmployeeID, ExpiryDate)
    INCLUDE (CourseCode, QueueStatus, DaysOverdue);
```
- Backs Workflow 2's cursor, which scans the queue by employee and age-of-expiry.

Full inventory: clustered PK (Phase I) + this filtered index + this covering index + 2 supporting indexes for the compliance/dept-stats reports — 5 total, justified in `optimization/index_analysis_notes.md`.

---

## 4. Performance proof (`optimization/index_performance_compare.sql`)

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT tr.TrainingRequestID, tr.BusinessEmployeeID, tr.CourseCode, tr.EnrollmentDate, tr.DepartmentID
FROM HRTrainingOps.TrainingRequests AS tr
WHERE tr.RequestStatus = N'Pending'
ORDER BY tr.EnrollmentDate DESC;
```
```sql
SET SHOWPLAN_TEXT ON;
SELECT tr.TrainingRequestID, ... FROM HRTrainingOps.TrainingRequests AS tr WHERE tr.RequestStatus = N'Pending';
SET SHOWPLAN_TEXT OFF;
```
- Run once **before** `indexes.sql` (baseline — expect Clustered Index Scan) and once **after** (expect Index Seek on `IX_TrainingRequests_Pending`).
- Queries are chosen to map 1:1 to each index, so the plan change (Scan → Seek) is unambiguous even on small sample data.
- `sys.dm_db_index_usage_stats` (Section B) backs this up with actual seek/scan counts, not just estimated plans.

---

## 5. My stored procedures

### `usp_RunComplianceReport` — the dynamic SQL requirement

```sql
IF @DepartmentName IS NOT NULL
    SET @where += N' AND d.Name = @pDepartmentName';
...
EXEC sys.sp_executesql
    @sql,
    N'@pDepartmentName NVARCHAR(50), @pCourseCode NVARCHAR(10), @pFromDate DATE, @pToDate DATE',
    @pDepartmentName = @DepartmentName, @pCourseCode = @CourseCode, ...;
```
- Predicate fragments are built dynamically, but **values never touch the string** — they go through `sp_executesql`'s parameter list. That's what stops SQL injection and lets the plan cache reuse compiled plans across different filter combinations.
- A `CASE` expression computes `ComplianceFlag` (`Compliant`/`In Progress`/`Non-Compliant`/`Review`) so the output is decision-ready, not just raw rows.

### `usp_BatchUpdateExpiredCertifications` — Workflow 2, step 1

```sql
BEGIN TRANSACTION;
UPDATE HRTrainingOps.TrainingRequests SET RequestStatus = N'Expired'
WHERE RequestStatus = N'Completed' AND CertificationExpiryDate < @Cutoff;

INSERT INTO HRTrainingOps.ExpiredCertificationQueue (...)
SELECT ... FROM HRTrainingOps.TrainingRequests AS tr
WHERE ... AND NOT EXISTS (SELECT 1 FROM HRTrainingOps.ExpiredCertificationQueue AS q
                           WHERE q.TrainingRequestID = tr.TrainingRequestID);
SET @RowsQueued = @@ROWCOUNT;
COMMIT TRANSACTION;
```
- Two-step transaction: flip expired rows, then queue them — `NOT EXISTS` guard means re-running the batch never double-queues.
- `SET XACT_ABORT ON` + `TRY/CATCH` with `ROLLBACK`: either both steps apply or neither does.

### `usp_GetDepartmentTrainingStats` — department reporting

```sql
SELECT d.DepartmentID, d.Name AS DepartmentName,
       COUNT(tr.TrainingRequestID) AS TotalEnrollments,
       SUM(CASE WHEN tr.RequestStatus = N'Pending' THEN 1 ELSE 0 END) AS PendingCount,
       AVG(tr.Score) AS AverageScore
FROM HumanResources.Department AS d
LEFT JOIN HRTrainingOps.TrainingRequests AS tr ON tr.DepartmentID = d.DepartmentID
WHERE (@DepartmentID IS NULL OR d.DepartmentID = @DepartmentID)
GROUP BY d.DepartmentID, d.Name;
```
- `LEFT JOIN` from `Department` so zero-enrollment departments still show up with zero counts — "no data" is itself a compliance finding.
- `@DepartmentID IS NULL OR ...` lets one procedure serve both "all departments" and "one department."

---

## 6. My cursors

### Static cursor — `usp_ProcessExpiryQueueWithCursor`

```sql
DECLARE expiry_cursor CURSOR STATIC LOCAL FOR
    SELECT q.QueueID, q.BusinessEmployeeID, q.CourseCode, q.ExpiryDate, q.DaysOverdue
    FROM HRTrainingOps.ExpiredCertificationQueue AS q
    WHERE q.QueueStatus = N'Pending Review'
    ORDER BY q.DaysOverdue DESC, q.QueueID;

OPEN expiry_cursor;
FETCH NEXT FROM expiry_cursor INTO @QueueID, @BusinessEmployeeID, @CourseCode, @ExpiryDate, @DaysOverdue;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO HRTrainingOps.NotificationLog (...) VALUES (...);
    UPDATE HRTrainingOps.ExpiredCertificationQueue SET QueueStatus = N'Notified' WHERE QueueID = @QueueID;
    FETCH NEXT FROM expiry_cursor INTO ...;
END;
```
- **STATIC** because this walk needs a stable snapshot and guaranteed order, not visibility into concurrent writes — cheaper than dynamic for this job.
- `CATCH` checks `CURSOR_STATUS` before close/deallocate, so cleanup never errors on a cursor that's already closed or never opened.

### Dynamic cursor — `usp_DynamicDepartmentNotification`

```sql
INSERT INTO #DeptGaps (DepartmentID, DepartmentName, MissingCount, SampleEmployeeID)
SELECT d.DepartmentID, d.Name, COUNT(*), MIN(edh.BusinessEntityID)
FROM HumanResources.Department AS d
INNER JOIN HumanResources.EmployeeDepartmentHistory AS edh ON ... AND edh.EndDate IS NULL
INNER JOIN HRTrainingOps.DepartmentTrainingRequirement AS req ON ... AND req.IsRequired = 1
WHERE NOT EXISTS (SELECT 1 FROM HRTrainingOps.TrainingRequests AS tr WHERE ...)
GROUP BY d.DepartmentID, d.Name
HAVING COUNT(*) > 0;

DECLARE dept_cursor CURSOR DYNAMIC LOCAL FOR
    SELECT DepartmentID, DepartmentName, MissingCount, SampleEmployeeID FROM #DeptGaps;
```
- Gap **detection** is set-based (`JOIN` + `NOT EXISTS` + `GROUP BY/HAVING`) — the harder part, done the normally-correct way.
- Notification **generation** walks the staged result with `CURSOR DYNAMIC` specifically to satisfy the spec's requirement to demonstrate that cursor type — I can explain in Q&A that DYNAMIC reflects underlying changes mid-fetch (STATIC doesn't), even though this particular loop doesn't mutate `#DeptGaps` while iterating.

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

Run each file **as a whole**, not statement-by-statement — `test_cases.sql` is sequential (later sections depend on data seeded earlier), and the SHOWPLAN section needs to stay in the same session as the rest. Both files are idempotent, safe to re-run more than once live.

---

## 9. Anticipated Q&A — points I need to be able to explain cold

- **Why DENY instead of just not granting?** Not granting only blocks access if no *other* grant (direct or via another role) exists. `DENY` overrides any grant unconditionally.
- **Why a filtered index instead of indexing the whole table?** Smaller index → less disk, faster maintenance on every INSERT/UPDATE, and it's covering for exactly the query shape that runs most often.
- **Static vs. dynamic cursor?** Static snapshots at `OPEN` (cheaper, stable order); dynamic re-reflects table changes as you fetch (more overhead, only needed when the loop must observe concurrent changes). Static for the queue walk, dynamic for the department-gap walk (spec requirement).
- **Why `sp_executesql` and not `EXEC(@sql)`?** Parameterization prevents SQL injection and allows plan-cache reuse; string-only `EXEC` forces a fresh compile — and is injectable — for every distinct filter combination.
- **What happens if `usp_BatchUpdateExpiredCertifications` fails halfway?** `XACT_ABORT ON` + `TRY/CATCH` with `ROLLBACK` means the `UPDATE` and `INSERT` either both apply or neither does.
