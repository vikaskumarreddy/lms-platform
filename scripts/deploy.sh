#!/bin/bash
set -e

echo "=== Axisora Forge Academy LMS Deployment ==="

# Check if .env exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Copy .env.example to .env and configure."
    exit 1
fi

# Load environment variables
export 

echo "Building and starting all services..."
cd docker
docker compose up -d --build

echo ""
echo "=== Deployment Complete ==="
echo "Backend API: http://localhost:8080"
echo "Swagger UI: http://localhost:8080/swagger-ui.html"
echo "Admin Portal: http://localhost:4200"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000"
echo ""
echo "Use 'docker compose logs -f' to view logs."
