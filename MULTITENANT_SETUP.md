# Multi-Tenant SaaS Architecture - Setup Guide

## Overview

The LMS platform is now a **multi-tenant SaaS** with Organizations as the top-level entity.

### User Roles & Access

| Role | Domain | Menus Visible | Permissions |
|------|--------|---------------|-------------|
| **Super Admin (ADMIN)** | localhost:4200 | All + Organizations | Create/manage orgs, create org admins |
| **Org Admin (INSTITUTE_ADMIN)** | tenant.localhost:4200 | All except Organizations | Manage faculty, students, batches in org |
| **Faculty (INSTRUCTOR)** | tenant.localhost:4200 | Limited | Create assignments, exams, grade students |
| **Student (STUDENT)** | tenant.localhost:4200 | Student portal | View courses, submit assignments |

---

## Domain-Based Tenant Resolution

The system automatically resolves organizations from domain names:

```
localhost:4200 → Routes to "axisora" org (Super Admin portal)
axisora.localhost:4200 → Routes to "axisora" org (Org Admin portal)
tenant1.localhost:4200 → Routes to "tenant1" org (Org Admin portal)
acme.example.com → Routes to "acme" org (Org Admin portal)
```

---

## Creating Organizations & Admins

### 1. Create Organization (Super Admin)

**Backend Endpoint:** `POST /api/organizations`

```bash
curl -X POST http://localhost:8080/api/organizations \
  -H "Authorization: Bearer <super_admin_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Axisora Academy",
    "slug": "axisora",
    "domain": "axisora.example.com",
    "isActive": true
  }'
```

### 2. Create Organization Admin

**Backend Endpoint:** `POST /api/organizations/{id}/admin`

```bash
curl -X POST http://localhost:8080/api/organizations/1/admin \
  -H "Authorization: Bearer <super_admin_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@axisora.com",
    "name": "Axisora Admin",
    "password": "secure_password_123",
    "phone": "+1234567890"
  }'
```

### 3. Create Faculty (Org Admin)

**Frontend:** Navigate to tenant domain, login as org admin, go to "👨‍🏫 Faculty" > "+ Create Faculty"

**API Endpoint:** `POST /api/org/faculty`

```bash
curl -X POST http://axisora.localhost:8080/api/org/faculty \
  -H "Authorization: Bearer <org_admin_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "faculty@axisora.com",
    "name": "Dr. Faculty",
    "password": "faculty_password_123",
    "phone": "+1987654321"
  }'
```

---

## Frontend Setup (localhost Testing)

### Edit Hosts File

Add to your hosts file:
```
127.0.0.1 localhost
127.0.0.1 axisora.localhost
127.0.0.1 tenant1.localhost
127.0.0.1 acme.localhost
```

### Access Portals

```
Super Admin: http://localhost:4200
Org Admin (Axisora): http://axisora.localhost:4200
Org Admin (Tenant1): http://tenant1.localhost:4200
```

---

## Architecture Components

### TenantInterceptor
- Intercepts requests and resolves tenant from: JWT claim → Header → Domain
- Sets OrganizationContext for scoped data access
- Clears context after response (prevents leakage)

### OrganizationContext (Thread-Local)
- Holds current organization per request thread
- Used by services to scope queries to current tenant
- Automatically cleared after request

### Role-Based Menu Visibility
- AuthService provides: `isSuperAdmin`, `isOrgAdmin`, `userRole`, `organizationId`
- Admin layout uses `*ngIf` to show/hide menus based on role
- Organizations menu only visible to Super Admin

### User Service Organization Scoping
- `getFacultyInCurrentOrganization()` - Gets faculty for current org
- `getStudentsInCurrentOrganization()` - Gets students for current org
- `createFacultyInCurrentOrganization()` - Creates faculty in current org

---

## Key Files Modified/Created

**Backend:**
- `TenantInterceptor.java` - Domain-based tenant resolution
- `OrganizationService.java`, `OrganizationController.java` - Org management
- `FacultyDirectoryController.java` - Organization-scoped faculty management
- `UserRepository.java` - Added org-scoped query methods
- `UserService.java` - Added org-scoped user methods
- `AuthService.java` - Updated to include org_id in JWT

**Frontend:**
- `AuthService.ts` - Added `isSuperAdmin`, `isOrgAdmin`, `organizationId` properties
- `admin-layout.component.ts` - Role-based menu visibility
- `organizations.component.ts` - Organizations CRUD UI

---

## JWT Token Example

```json
{
  "sub": "admin@axisora.com",
  "organization_id": 1,
  "role": "INSTITUTE_ADMIN",
  "iat": 1723577400,
  "exp": 1723663800
}
```

The `organization_id` claim is used by TenantInterceptor for automatic tenant resolution.

