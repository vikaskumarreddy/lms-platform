# Axisora Forge Academy LMS - Deployment Guide

## Prerequisites
- Ubuntu LTS VPS (Hostinger recommended)
- Docker and Docker Compose installed
- Domain name (optional)
- SSL certificate (Let's Encrypt)

## Quick Start

1. Clone the repository
2. Copy .env.example to .env and configure
3. Run: cd docker && docker compose up -d

## Services
- Backend API: http://localhost:8080
- Swagger UI: http://localhost:8080/swagger-ui.html
- Admin Portal: http://localhost:4200
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

## SSL Setup
Use certbot to get Let's Encrypt SSL certificates:
certbot --nginx -d yourdomain.com

## Backups
Run scripts/backup.sh to create database backups.
Run scripts/restore.sh <backup_file> to restore.

## Scaling
The architecture supports horizontal scaling by:
- Adding multiple backend instances behind Nginx
- Using a separate database server
- Adding a CDN for static content
- Using cloud storage for files
