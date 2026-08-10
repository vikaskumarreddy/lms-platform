#!/bin/bash
set -e

if [ -z "" ]; then
    echo "Usage: ./restore.sh <backup_file>"
    exit 1
fi

BACKUP_FILE=

if [ ! -f "" ]; then
    echo "Error: Backup file not found: "
    exit 1
fi

echo "Restoring from: "
gunzip -c "" | docker exec -i lms_postgres psql -U lms lms

echo "Restore complete."
