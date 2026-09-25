#!/bin/bash
set -e

# ==============================================================================
# Script: deploy_frontend_s3.sh
# Purpose: Build and deploy Angular Admin Portal to AWS S3 & CloudFront (Architecture A)
# Usage:
#   ./scripts/deploy_frontend_s3.sh <S3_BUCKET_NAME> <CLOUDFRONT_DISTRIBUTION_ID>
# Or configure S3_BUCKET_NAME and CLOUDFRONT_DIST_ID in .env
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load from .env if available
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

BUCKET_NAME="${1:-$S3_BUCKET_NAME}"
DISTRIBUTION_ID="${2:-$CLOUDFRONT_DIST_ID}"

if [ -z "$BUCKET_NAME" ]; then
    echo "ERROR: S3 bucket name is required."
    echo "Usage: $0 <s3-bucket-name> [cloudfront-distribution-id]"
    echo "Or set S3_BUCKET_NAME in your .env file."
    exit 1
fi

echo "=== Deploying Angular Admin Portal to AWS S3 / CloudFront ==="
echo "Target S3 Bucket:       $BUCKET_NAME"
echo "CloudFront Dist ID:     ${DISTRIBUTION_ID:-<None specified>}"
echo ""

# 1. Build Angular production bundle
echo "[1/4] Building Angular Admin Portal for production..."
cd "$ROOT_DIR/admin-portal"
npm install --silent
npm run build -- --configuration production

DIST_PATH="$ROOT_DIR/admin-portal/dist/admin-portal"
if [ ! -d "$DIST_PATH" ]; then
    echo "ERROR: Build directory $DIST_PATH does not exist!"
    exit 1
fi

# 2. Sync hashed immutable assets (JS, CSS, fonts, images) with 1-year cache
echo "[2/4] Syncing hashed assets to s3://$BUCKET_NAME with aggressive caching..."
aws s3 sync "$DIST_PATH" "s3://$BUCKET_NAME" \
    --delete \
    --exclude "index.html" \
    --cache-control "public, max-age=31536000, immutable"

# 3. Sync index.html with no-cache headers to prevent stale SPA caches
echo "[3/4] Uploading index.html with no-cache headers..."
aws s3 cp "$DIST_PATH/index.html" "s3://$BUCKET_NAME/index.html" \
    --cache-control "no-cache, no-store, must-revalidate" \
    --content-type "text/html"

# 4. Invalidate CloudFront distribution if provided
if [ -n "$DISTRIBUTION_ID" ]; then
    echo "[4/4] Invalidating CloudFront cache for distribution $DISTRIBUTION_ID..."
    aws cloudfront create-invalidation \
        --distribution-id "$DISTRIBUTION_ID" \
        --paths "/*"
    echo "CloudFront invalidation triggered successfully!"
else
    echo "[4/4] Skipping CloudFront invalidation (no distribution ID provided)."
fi

echo ""
echo "=== Frontend Deployment Complete ==="
