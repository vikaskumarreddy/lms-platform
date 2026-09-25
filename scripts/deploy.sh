#!/bin/bash
set -e

echo "=== Axisora Forge Academy LMS Deployment ==="

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Copy .env.example to .env and configure."
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

MODE="${1:-${DEPLOY_MODE:-all}}"

cd docker

if [ "$MODE" == "--backend-only" ] || [ "$MODE" == "--architecture-a" ] || [ "$MODE" == "backend-only" ]; then
    echo "Starting in Architecture A mode (Backend, Postgres, Redis only)..."
    docker compose up -d --build postgres redis backend
    echo ""
    echo "=== Deployment Complete (Architecture A - EC2 Backend) ==="
    echo "Backend API: http://localhost:8080"
    echo "Swagger UI: http://localhost:8080/swagger-ui.html"
    echo "Frontend is deployed via AWS S3 + CloudFront."
else
    echo "Building and starting all services (Full Stack)..."
    docker compose up -d --build
    echo ""
    echo "=== Deployment Complete (Full Stack) ==="
    echo "Backend API: http://localhost:8080"
    echo "Swagger UI: http://localhost:8080/swagger-ui.html"
    echo "Admin Portal: http://localhost:80 (and :4200)"
fi

echo ""
echo "Use 'docker compose logs -f' to view logs."

