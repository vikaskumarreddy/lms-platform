#!/bin/bash
set -e

echo "=== 1. Stopping backend container ==="
docker stop lms_backend

echo "=== 2. Recreating database on Postgres ==="
docker cp /home/ubuntu/lms_db_dump.dump lms_postgres:/tmp/lms_db_dump.dump
docker exec -t lms_postgres psql -U lms -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'lms' AND pid != pg_backend_pid();" || true
docker exec -t lms_postgres psql -U lms -d postgres -c "DROP DATABASE IF EXISTS lms;"
docker exec -t lms_postgres psql -U lms -d postgres -c "CREATE DATABASE lms;"

echo "=== 3. Restoring dump to Postgres ==="
docker exec -t lms_postgres pg_restore -U lms -d lms /tmp/lms_db_dump.dump || true

echo "=== 4. Restoring uploaded media files ==="
VOL_PATH=$(docker volume inspect docker_backend_uploads --format '{{.Mountpoint}}')
echo "Volume path: $VOL_PATH"
sudo tar -xzf /home/ubuntu/local_uploads.tar.gz -C "$VOL_PATH"
sudo chown -R 1000:1000 "$VOL_PATH" 2>/dev/null || sudo chown -R root:root "$VOL_PATH"

echo "=== 5. Starting backend container ==="
docker start lms_backend

echo "=== Database and Uploads Restore Completed Successfully ==="
