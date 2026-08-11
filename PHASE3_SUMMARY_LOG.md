# HRTrainingOps — Phase III Summary Log

**Date:** 2026-08-11  
**Lead:** Dhruv Patel (Security & Optimization) · Integration support: Sahil Maniya  
**Branch target:** local workspace / `main` when committed  

---

## Objectives Completed

| Requirement | Output | Status |
|-------------|--------|--------|
| Create indexes and compare performance | `optimization/indexes.sql`, `optimization/index_performance_compare.sql`, `optimization/index_analysis_notes.md` | Done |
| Finalize modular organization | Root folders retained; Phase III artifacts added at repo root | Done |
| Validate schema with sample data | `test_data.sql` | Done |
| Permission testing path | Existing `security/test_cases.sql` (run after final deploy) | Ready |
| Full deployment script | `final_script.sql` | Done |
| Updated README + summary log | `README.md`, this file | Done |

---

## Files Added (Phase III)

```
optimization/
├── indexes.sql                      Create clustered checklist + NCIs + filtered INCLUDE
├── index_performance_compare.sql    STATISTICS IO/TIME + usage stats + SHOWPLAN_TEXT
└── index_analysis_notes.md          Justification + pre/post capture worksheet

test_data.sql                        Full sample load (courses, requirements, enrollments,
                                     queue, review, notifications)
final_script.sql                     Master SQLCMD deploy: Phase I → II → data → indexes
PHASE3_SUMMARY_LOG.md                This summary
```

---

## Index Checklist (Course Rubric)

| Required | Implementation |
|----------|----------------|
| Clustered | `PK_TrainingRequests` on `TrainingRequests.TrainingRequestID` (Phase I schema) |
| Nonclustered | `IX_ExpiredQueue_EmployeeExpiry` on `(BusinessEmployeeID, ExpiryDate)` |
| Filtered / INCLUDE | `IX_TrainingRequests_Pending` WHERE `RequestStatus = 'Pending'` INCLUDE `(CourseCode, BusinessEmployeeID, DepartmentID)` + key `EnrollmentDate` |

Supporting (demo/compliance): `IX_TrainingRequests_DeptStatus`, `IX_TrainingRequests_Expiry`.

---

## Instructor Demo Sequence

1. Clean AdventureWorks2022 + SQLCMD Mode  
2. Run `final_script.sql` (set `ProjectRoot`)  
3. Run `security/test_cases.sql` — enrollment, review, dynamic SQL, GRANT/DENY  
4. Run `optimization/index_performance_compare.sql` — capture Messages logical reads + SHOWPLAN  
5. Optional: drop Phase III NCIs, re-measure, recreate via `indexes.sql` for live before/after  

---

## Validation Notes

- `test_data.sql` is idempotent (`NOT EXISTS` guards) and uses live AdventureWorks employees / departments.  
- `final_script.sql` creates demo logins via `security/permissions.sql` — execute as **sysadmin**.  
- Individual object scripts may print their own Phase II built-in test cases when included; expected during deploy.  
- Record lab-specific logical-read numbers in `optimization/index_analysis_notes.md` Section 3 during demo prep.  
- Save SSMS screenshots under `Screenshot/Sahil`, `Screenshot/Parth`, `Screenshot/Dhruv`.

---

## Known Limitations

- Absolute IO improvement is modest on small sample sets; emphasize plan shape (Seek vs Scan) and index usage DMVs.  
- `SHOWPLAN_TEXT` batch must not be mixed with data-returning batches incorrectly — script toggles ON for a single statement then OFF.  
- Phase III does not alter Phase I/II object definitions beyond adding indexes and data.
