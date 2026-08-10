#!/bin/bash
set -e

BACKUP_DIR="/backups"
DATE=
BACKUP_FILE="/lms_backup_.sql.gz"

mkdir -p 

echo "Creating PostgreSQL backup..."
docker exec lms_postgres pg_dump -U lms lms | gzip > 

echo "Backup created: "

# Keep only last 7 days of backups
find  -name "lms_backup_*.sql.gz" -mtime +7 -delete

echo "Old backups cleaned up."
