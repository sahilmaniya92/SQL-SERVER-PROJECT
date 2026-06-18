# HRTrainingOps — Entity Relationship Diagram

## Files

| File | Purpose |
|------|---------|
| `hrtrainingops_erd.drawio` | Editable diagram source (draw.io / diagrams.net) |
| `hrtrainingops_erd.pdf` | **Export this for Blackboard submission** |

## How to Open & Export PDF

1. Go to [https://app.diagrams.net/](https://app.diagrams.net/)
2. **File → Open from → Device** → select `hrtrainingops_erd.drawio`
3. Review layout (zoom to fit: **View → Fit Page**)
4. **File → Export as → PDF**
   - Border: 10 px
   - Fit to: 1 page(s)
   - Save as `hrtrainingops_erd.pdf`

## Diagram Features

- **Crow's Foot notation** on all relationships (1:1, 1:M)
- **Full attribute list** with data types per entity
- **PK / FK / UQ** key notation with color coding
- **Zoned layout:** External · Core · Workflow · Logging
- **Legend** with cardinality symbols and entity color key
- **Relationship summary table** on diagram
- **Title banner** and footer with team / schema metadata

## Entity Summary (7 Tables)

| Entity | Zone | Role |
|--------|------|------|
| `TrainingCourse` | Core | Course catalog |
| `TrainingRequests` | Core (Hub) | Central enrollment record |
| `DepartmentTrainingRequirement` | Core | Dept-to-course rules |
| `ExpiredCertificationQueue` | Workflow | Expiry processing queue |
| `CertificationReleaseReview` | Workflow | HR review decisions |
| `NotificationLog` | Logging | Employee notifications |
| `ErrorLog` | Logging | Errors and audit trail |

## External References

| AdventureWorks Table | Referenced By |
|---------------------|---------------|
| `HumanResources.Employee` | TrainingRequests, ExpiredQueue, NotificationLog |
| `HumanResources.Department` | TrainingRequests, DeptRequirement |

## Normalization

All tables satisfy **Third Normal Form (3NF)**:

- No repeating groups
- Non-key attributes depend on the whole primary key
- No transitive dependencies between non-key attributes
