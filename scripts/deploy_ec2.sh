#!/bin/bash
set -e

# ==============================================================================
# Axisora Forge LMS - Automated EC2 Deployer (Bash / Linux / macOS / Git Bash)
# ==============================================================================

SERVICE="${1:-all}"
HOST_IP="${HOST_IP:-100.61.94.14}"
KEY_PATH="${KEY_PATH:-$HOME/.aws/lms-key.pem}"
USER="${EC2_USER:-ubuntu}"
REMOTE_DIR="${REMOTE_DIR:-/opt/lms}"

case "$SERVICE" in
    admin|admin-portal)
        COMPOSE_TARGET="admin-portal"
        FOLDERS="admin-portal docker"
        ;;
    backend)
        COMPOSE_TARGET="backend"
        FOLDERS="backend docker"
        ;;
    all|*)
        SERVICE="all"
        COMPOSE_TARGET="backend admin-portal"
        FOLDERS="backend admin-portal docker scripts"
        ;;
esac

echo "=========================================================="
echo "       Axisora Forge LMS - Automated EC2 Deployer         "
echo "=========================================================="
echo "  Target Host  : $USER@$HOST_IP"
echo "  Service(s)   : $SERVICE (Docker: $COMPOSE_TARGET)"
echo "  SSH Key      : $KEY_PATH"
echo "=========================================================="

if [ ! -f "$KEY_PATH" ]; then
    echo "[ERROR] SSH key not found at: $KEY_PATH"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

TEMP_ARCHIVE="deploy_temp_$$.tar.gz"

cleanup() {
    rm -f "$TEMP_ARCHIVE"
}
trap cleanup EXIT

echo ""
echo "[1/4] Compressing source files ($FOLDERS)..."
tar --exclude="target" \
    --exclude="node_modules" \
    --exclude=".angular" \
    --exclude=".git" \
    --exclude=".idea" \
    --exclude=".vscode" \
    --exclude="mobile-app" \
    --exclude="*.tar.gz" \
    --exclude="*.log" \
    -czf "$TEMP_ARCHIVE" $FOLDERS

echo "[2/4] Uploading package to EC2..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no "$TEMP_ARCHIVE" "${USER}@${HOST_IP}:/tmp/deploy_bundle.tar.gz"

echo "[3/4] Rebuilding Docker container(s) on EC2..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "${USER}@${HOST_IP}" bash <<EOF
set -e
echo "--> Extracting source files into $REMOTE_DIR..."
tar -xzf /tmp/deploy_bundle.tar.gz -C $REMOTE_DIR/
rm -f /tmp/deploy_bundle.tar.gz

echo "--> Rebuilding container(s): $COMPOSE_TARGET..."
cd $REMOTE_DIR/docker
docker compose up -d --build $COMPOSE_TARGET

echo "--> Current container status:"
docker compose ps
EOF

echo ""
echo "[4/4] Deployment Finished Successfully!"
echo "=========================================================="
echo "  Admin Portal : http://${HOST_IP}"
echo "  Backend API  : http://${HOST_IP}:8080"
echo "  Swagger UI   : http://${HOST_IP}:8080/swagger-ui/index.html"
echo "  OpenAPI Spec : http://${HOST_IP}/api-docs"
echo "=========================================================="
