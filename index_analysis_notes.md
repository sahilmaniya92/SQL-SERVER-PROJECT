# HRTrainingOps — Index Analysis Notes (Phase III)

**Owner:** Dhruv Patel (Security & Optimization Lead)  
**Database:** AdventureWorks2022 · Schema `HRTrainingOps`  
**Scripts:** `optimization/indexes.sql`, `optimization/index_performance_compare.sql`

---

## 1. Index Inventory

| # | Index | Table | Type | Key / Definition | Business Purpose |
|---|-------|-------|------|------------------|------------------|
| 1 | `PK_TrainingRequests` | `TrainingRequests` | **Clustered** (Phase I) | `TrainingRequestID` | Primary access path / RID lookups avoided |
| 2 | `IX_ExpiredQueue_EmployeeExpiry` | `ExpiredCertificationQueue` | **Nonclustered** | `(BusinessEmployeeID, ExpiryDate)` INCLUDE `CourseCode, QueueStatus, DaysOverdue` | Expiry queue scans by employee and overdue date |
| 3 | `IX_TrainingRequests_Pending` | `TrainingRequests` | **Filtered + INCLUDE** | `EnrollmentDate` INCLUDE `CourseCode, BusinessEmployeeID, DepartmentID` **WHERE** `RequestStatus = 'Pending'` | Pending follow-up lists for clerks/managers |
| — | `IX_TrainingRequests_DeptStatus` | `TrainingRequests` | Supporting NCI | `(DepartmentID, RequestStatus)` INCLUDE reporting columns | Compliance report / dept stats |
| — | `IX_TrainingRequests_Expiry` | `TrainingRequests` | Supporting NCI | `(CertificationExpiryDate, RequestStatus)` INCLUDE keys | Batch expiry queue population |

Also present from Phase I: filtered unique `UX_TrainingRequests_ActiveEnrollment` on `(BusinessEmployeeID, CourseCode)` where status is Pending/Completed.

---

## 2. How to Capture Pre / Post Evidence (Demo Steps)

Use the same sample data (`test_data.sql`) for both runs so row counts match.

### Baseline (BEFORE Phase III indexes)

1. Deploy schema + Phase II objects + `test_data.sql`
2. Optionally drop only Phase III NCIs if re-running:
   ```sql
   DROP INDEX IF EXISTS IX_ExpiredQueue_EmployeeExpiry ON HRTrainingOps.ExpiredCertificationQueue;
   DROP INDEX IF EXISTS IX_TrainingRequests_Pending ON HRTrainingOps.TrainingRequests;
   DROP INDEX IF EXISTS IX_TrainingRequests_DeptStatus ON HRTrainingOps.TrainingRequests;
   DROP INDEX IF EXISTS IX_TrainingRequests_Expiry ON HRTrainingOps.TrainingRequests;
   ```
   (`DROP INDEX IF EXISTS` requires SQL Server 2016+)
3. Run `optimization/index_performance_compare.sql`
4. In SSMS **Messages**, copy logical reads for Query 1–3

### After indexes

1. Run `optimization/indexes.sql`
2. Run `optimization/index_performance_compare.sql` again
3. Confirm seeks / lower logical reads and update the results table below with your lab numbers

### SHOWPLAN

Section C of the compare script uses `SET SHOWPLAN_TEXT ON`.  
**Expected after indexing (Query 1):** Index Seek (or Scan of the small filtered index) on `IX_TrainingRequests_Pending` rather than Clustered Index Scan of all enrollment history.

---

## 3. Results Table (fill during lab / demo)

| Query | Before (logical reads) | After (logical reads) | Plan observation |
|-------|------------------------|-----------------------|------------------|
| Q1 Pending enrollments | _record from Messages_ | _record from Messages_ | Seek/scan on `IX_TrainingRequests_Pending` |
| Q2 Dept compliance (Dept 7) | _record_ | _record_ | Prefer `IX_TrainingRequests_DeptStatus` |
| Q3 Expiry queue by employee | _record_ | _record_ | Prefer `IX_ExpiredQueue_EmployeeExpiry` |

> Tip: With small sample volumes, absolute read counts may stay low; emphasize **operator change** in the plan (Scan → Seek / filtered index use) and `sys.dm_db_index_usage_stats` seeks after the workload.

---

## 4. Justification Summary (Q&A Ready)

| Choice | Why |
|--------|-----|
| Clustered on `TrainingRequestID` | Natural surrogate PK; identity inserts append; most FK lookups by ID |
| NCI on queue `(BusinessEmployeeID, ExpiryDate)` | Workflow 2 processes / notifies by employee and age of expiry |
| Filtered Pending + INCLUDE | Pending subset is hot path; INCLUDE covers covering columns so key lookups are avoided |
| Supporting dept/status index | Compliance and manager views filter heavily on department + status |

---

## 5. Reproducibility Checklist

- [ ] `test_data.sql` loaded (same rows for before/after)
- [ ] Baseline STATISTICS IO captured
- [ ] `indexes.sql` executed
- [ ] Post STATISTICS IO + SHOWPLAN captured
- [ ] Screenshots saved under `Screenshot/Dhruv/` for instructor review
