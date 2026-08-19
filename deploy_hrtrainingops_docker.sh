#!/usr/bin/env bash
set -euo pipefail

# HRTrainingOps deployment for macOS/Linux via a local Docker SQL Server container.
# final_script.sql is written for SSMS/SQLCMD-mode on Windows (backslash :r paths),
# so this script replays the same file order directly against the container's own
# sqlcmd, with QUOTED_IDENTIFIER ON set explicitly (Linux sqlcmd doesn't default it
# the way SSMS does, which breaks the filtered index in schema/03).
#
# Usage:
#   ./deploy_hrtrainingops_docker.sh
#   CONTAINER=sqlserver-dev SQL_USER=sa SQL_PASSWORD='...' ./deploy_hrtrainingops_docker.sh

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CONTAINER="${CONTAINER:-sqlserver-dev}"
SQL_USER="${SQL_USER:-sa}"
SQL_PASSWORD="${SQL_PASSWORD:-}"
REMOTE_PATH="/tmp/HRTrainingOps-deploy"

if [ -z "$SQL_PASSWORD" ]; then
  read -r -s -p "Enter SQL password for user '$SQL_USER': " SQL_PASSWORD
  echo
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "ERROR: container '$CONTAINER' is not running. Start it first (docker start $CONTAINER)."
  exit 1
fi

echo "=== HRTrainingOps Deployment (Docker) ==="
echo "Project root : $PROJECT_ROOT"
echo "Container    : $CONTAINER"
echo "SQL User     : $SQL_USER"

echo "Copying project files into container..."
docker exec "$CONTAINER" mkdir -p "$REMOTE_PATH"
docker cp "$PROJECT_ROOT/." "$CONTAINER:$REMOTE_PATH/"

FILES=(
  schema/01_create_schema.sql
  schema/02_training_course.sql
  schema/03_training_requests.sql
  schema/04_department_training_requirement.sql
  schema/05_expired_certification_queue.sql
  schema/06_certification_release_review.sql
  schema/07_notification_log.sql
  schema/08_error_log.sql
  functions/fn_TrainingScoreClass.sql
  functions/fn_GetEmployeeTrainingData.sql
  views/vEmployeeTrainingSummary.sql
  views/vw_PendingCertifications.sql
  views/vw_ManagerDepartmentCompliance.sql
  views/vw_EmployeeSelfService.sql
  triggers/trg_TrainingRequests_ValidateEnrollment.sql
  triggers/trg_TrainingRequests_AuditStatusChange.sql
  triggers/trg_ExpiredQueue_StatusTransition.sql
  procedures/usp_EnrollEmployeeInCourse.sql
  procedures/usp_GetTrainingRequests.sql
  procedures/usp_ProcessCertificationReview.sql
  procedures/usp_BatchUpdateExpiredCertifications.sql
  procedures/usp_GetDepartmentTrainingStats.sql
  procedures/usp_RunComplianceReport.sql
  procedures/expired_certification_review_cursor.sql
  procedures/usp_DynamicDepartmentNotification.sql
  security/permissions.sql
  test_data.sql
  optimization/indexes.sql
)

for f in "${FILES[@]}"; do
  echo "=== RUNNING: $f ==="
  docker exec -i -e SQL_USER="$SQL_USER" -e SQL_PASSWORD="$SQL_PASSWORD" -e TARGET_FILE="$REMOTE_PATH/$f" "$CONTAINER" sh -c '
    { printf "SET QUOTED_IDENTIFIER ON;\nSET ANSI_NULLS ON;\nGO\n"; cat "$TARGET_FILE"; } | \
    /opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1 -U "$SQL_USER" -P "$SQL_PASSWORD" -C -b
  '
done

echo "Deployment completed successfully."
