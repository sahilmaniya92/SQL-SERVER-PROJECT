#!/usr/bin/env bash
set -euo pipefail

# HRTrainingOps deployment shell script
# Runs final_script.sql using sqlcmd (SQLCMD mode include files are handled by sqlcmd)
#
# Usage examples:
#   ./deploy_hrtrainingops.sh
#   SQL_SERVER=localhost,1433 SQL_USER=sa SQL_PASSWORD='YourPassword' ./deploy_hrtrainingops.sh
#   PROJECT_ROOT="/d/ITS/SEM-2/SQL SERVER/PROJECT" ./deploy_hrtrainingops.sh

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
SQL_DATABASE="${SQL_DATABASE:-AdventureWorks2022}"
SQL_USER="${SQL_USER:-sa}"
SQL_PASSWORD="${SQL_PASSWORD:-}"
FINAL_SCRIPT="${FINAL_SCRIPT:-$PROJECT_ROOT/final_script.sql}"

echo "=== HRTrainingOps Deployment (.sh) ==="
echo "Project root : $PROJECT_ROOT"
echo "SQL Server   : $SQL_SERVER"
echo "Database     : $SQL_DATABASE"
echo "Script       : $FINAL_SCRIPT"

if ! command -v sqlcmd >/dev/null 2>&1; then
  echo "ERROR: sqlcmd not found. Install SQL Server command-line tools first."
  exit 1
fi

if [ ! -f "$FINAL_SCRIPT" ]; then
  echo "ERROR: final_script.sql not found at: $FINAL_SCRIPT"
  exit 1
fi

if [ -z "$SQL_PASSWORD" ]; then
  read -r -s -p "Enter SQL password for user '$SQL_USER': " SQL_PASSWORD
  echo
fi

echo "Running deployment..."
sqlcmd \
  -S "$SQL_SERVER" \
  -d "$SQL_DATABASE" \
  -U "$SQL_USER" \
  -P "$SQL_PASSWORD" \
  -b \
  -i "$FINAL_SCRIPT"

echo "Deployment completed successfully."
