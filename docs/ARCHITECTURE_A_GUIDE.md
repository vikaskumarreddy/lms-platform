# Architecture A: S3 + CloudFront Frontend & Direct EC2 Backend

This guide outlines the production deployment for **Architecture A**, designed for minimal monthly cost, high performance, global CDN distribution, and zero container overhead for the frontend.

---

## 1. Architectural Overview

```
                          Users & Mobile Apps
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │     AWS CloudFront (CDN)      │
                   │     https://yourdomain.com    │
                   │     • Free SSL / TLS          │
                   │     • Global Edge Caching     │
                   └───────────────┬───────────────┘
                                   │
                  ┌────────────────┴────────────────┐
                  │                                 │
         Route: /* (Static SPA)            Route: /api/* (REST API)
                  │                                 │
                  ▼                                 ▼
       ┌─────────────────────┐           ┌─────────────────────┐
       │    Amazon S3        │           │     Single EC2      │
       │  (Admin Portal SPA) │           │ (t4g.small / VPS)   │
       │  • index.html       │           │                     │
       │  • main.*.js        │           │ ┌─────────────────┐ │
       │  • assets/          │           │ │ Spring Boot API │ │
       │  (OAC Protected)    │           │ │ (Port 8080)     │ │
       └─────────────────────┘           │ ├─────────────────┤ │
                                         │ │ PostgreSQL      │ │
                                         │ ├─────────────────┤ │
                                         │ │ Redis           │ │
                                         │ └─────────────────┘ │
                                         └─────────────────────┘
```

### Key Advantages:
1. **Ultra-Low Cost**: Runs comfortably on a single `$10 - $15/month` EC2 instance (`t4g.small` or `t3.small`). S3 and CloudFront stay well within AWS Free Tier (1TB CloudFront transfer free each month).
2. **Zero Container Overhead for Frontend**: Static Angular files are served directly by S3 + CloudFront edge caches. No Node or Nginx container needed on EC2 for the frontend.
3. **No CORS Issues**: CloudFront routes both static frontend (`/*`) and API traffic (`/api/*`) under the exact same domain name (e.g. `https://lms.yourdomain.com`).
4. **Instant Global Delivery**: Frontend bundles are cached at hundreds of edge locations worldwide with 1-year immutable caching for hashed assets.
5. **Seamless Local Development**: Local `docker compose up` continues to work with 100% backward compatibility.

---

## 2. Infrastructure Setup (One-Time)

### Option A: Using AWS CloudFormation (Recommended)
An automated CloudFormation template is provided in [`aws/architecture-a.yml`](../aws/architecture-a.yml).

Run via AWS CLI:
```bash
aws cloudformation create-stack \
  --stack-name lms-architecture-a \
  --template-body file://aws/architecture-a.yml \
  --parameters \
      ParameterKey=EnvironmentName,ParameterValue=prod \
      ParameterKey=EC2BackendOriginHost,ParameterValue=<YOUR_EC2_PUBLIC_DNS_OR_IP> \
      ParameterKey=EC2BackendOriginPort,ParameterValue=8080 \
  --capabilities CAPABILITY_IAM
```

Once stack creation completes, check outputs for:
- `FrontendBucketName`: e.g. `lms-frontend-prod-123456789012-us-east-1`
- `CloudFrontDomainName`: e.g. `d111111abcdef8.cloudfront.net`
- `CloudFrontDistributionId`: e.g. `E1234567890ABC`

### Option B: Manual AWS Console Setup
1. **Create S3 Bucket**:
   - Name: `lms-admin-frontend-prod`
   - Keep "Block all public access" ENABLED.
2. **Create CloudFront Distribution**:
   - **Origin 1**: S3 bucket (`lms-admin-frontend-prod`), Origin Access Control (OAC) enabled.
   - **Origin 2**: Custom Origin pointing to your EC2 public IP or DNS on HTTP port `8080`.
   - **Default Behavior (`/*`)**: Target Origin 1 (S3), Cache Policy `CachingOptimized`.
   - **Behavior for `/api/*`**: Target Origin 2 (EC2), Cache Policy `CachingDisabled`, Origin Request Policy `AllViewerExceptHostHeader` (or forward all headers and query strings). Methods: `GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE`.
   - **Custom Error Pages**: Add error rule for HTTP `403` and `404` -> Response page path `/index.html` with HTTP `200` (required for Angular SPA client-side routing).

---

## 3. Deploying the Backend to EC2

On your EC2 server:

1. Clone or pull the repository:
   ```bash
   git clone https://github.com/your-org/lms-platform.git
   cd lms-platform
   ```

2. Configure your `.env` file:
   ```bash
   cp .env.example .env
   # Set your JWT secrets, database credentials, and Razorpay/PayU keys
   # Optional: add your CloudFront or custom domain to APP_CORS_ALLOWED_ORIGINS
   APP_CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://d111111abcdef8.cloudfront.net
   ```

3. Start backend services in Architecture A mode:
   ```bash
   ./scripts/deploy.sh --architecture-a
   ```
   *This starts only `postgres`, `redis`, and `backend` (port 8080), saving memory on EC2.*

---

## 4. Deploying the Frontend (Admin Portal) to S3 + CloudFront

From your local machine or CI/CD pipeline (GitHub Actions / GitLab CI):

### Using Bash (Linux / macOS / Git Bash):
```bash
./scripts/deploy_frontend_s3.sh <S3_BUCKET_NAME> <CLOUDFRONT_DISTRIBUTION_ID>
```

### Using PowerShell (Windows):
```powershell
.\scripts\deploy_frontend_s3.ps1 -BucketName "<S3_BUCKET_NAME>" -DistributionId "<CLOUDFRONT_DISTRIBUTION_ID>"
```

### What the deployment script does:
1. Compiles Angular with production optimizations (`npm run build -- --configuration production`).
2. Syncs hashed bundles (`*.js`, `*.css`, fonts, images) to S3 with `Cache-Control: public, max-age=31536000, immutable`.
3. Uploads `index.html` with `Cache-Control: no-cache, no-store, must-revalidate` so updates are instantly picked up by browsers.
4. Creates a CloudFront invalidation for `/*` so the new release is live immediately across all edge locations.

---

## 5. Local Development (Unchanged)

Local development remains 100% untouched and does not require AWS:

```bash
cd docker
docker compose up -d
```

- Admin Portal: `http://localhost:4200` (or `http://localhost:80`)
- Backend API: `http://localhost:8080/api`
- Swagger UI: `http://localhost:8080/swagger-ui.html`
