# Axisora Forge Academy LMS - Deployment Guide

## Deployment Architecture Options

### 1. Architecture A: S3 + CloudFront Frontend & Direct EC2 Backend (Recommended for AWS)
- **Frontend**: Angular Admin Portal deployed to AWS S3 & served globally via CloudFront CDN.
- **Backend**: Spring Boot, PostgreSQL, and Redis running on a single EC2 instance (`t4g.small` or `t3.small`).
- **Benefits**:
  - Lowest monthly cost ($5–$15/mo total).
  - No frontend container overhead on EC2.
  - Zero CORS issues (CloudFront routes `/*` to S3 and `/api/*` to EC2).
  - High availability and global edge caching for static assets.
- **Detailed Guide**: See [Architecture A Guide](ARCHITECTURE_A_GUIDE.md) and CloudFormation template [`aws/architecture-a.yml`](../aws/architecture-a.yml).

---

### 2. All-in-One Docker Deployment (Local Development & VPS)
Runs all services (`backend`, `postgres`, `redis`, and `admin-portal`) together on a single server or local machine.

#### Quick Start:
1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/lms-platform.git
   cd lms-platform
   ```
2. Copy `.env.example` to `.env` and configure credentials.
3. Run deployment script:
   ```bash
   ./scripts/deploy.sh
   ```
   Or via Docker Compose directly:
   ```bash
   cd docker
   docker compose up -d --build
   ```

#### Services:
- **Backend API**: http://localhost:8080
- **Swagger UI**: http://localhost:8080/swagger-ui.html
- **Admin Portal**: http://localhost:80 (and http://localhost:4200)

---

## Backups
- Run `scripts/backup.sh` to create PostgreSQL database backups.
- Run `scripts/restore.sh <backup_file>` to restore a backup.

