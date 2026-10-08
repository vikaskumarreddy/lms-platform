package com.institute.lms.interceptor;

import com.institute.lms.entity.Organization;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.security.JwtService;
import com.institute.lms.util.OrganizationContext;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.Optional;

/**
 * Intercepts every HTTP request and resolves the current tenant (Organization)
 * from one of four sources (in priority order):
 * <ol>
 *   <li>The {@code organization_id} claim in the JWT Bearer token (authenticated requests), or</li>
 *   <li>The {@code X-Tenant-ID} request header (API calls), or</li>
 *   <li>The {@code X-Tenant-Slug} request header (client subdomain, e.g. "yogasree"), or</li>
 *   <li>The request hostname/domain (for domain-based multi-tenancy)</li>
 * </ol>
 * The resolved organization is stored in {@link OrganizationContext} (a
 * thread-local). Hibernate's {@code @TenantId} DISCRIMINATOR strategy reads that
 * context on every query and injects {@code organization_id = ?}, guaranteeing
 * per-tenant isolation across all repositories/queries.
 *
 * <p>The context is cleared in {@link #afterCompletion} to prevent leakage.
 * No session/filter manipulation is performed here — that responsibility is
 * handled declaratively by the {@code @TenantId} + TenantIdentifierResolver.
 */
@Component
public class TenantInterceptor implements HandlerInterceptor {

    private final JwtService jwtService;
    private final OrganizationRepository organizationRepository;
    private final OrganizationContext organizationContext;

    public TenantInterceptor(JwtService jwtService, OrganizationRepository organizationRepository,
                             OrganizationContext organizationContext) {
        this.jwtService = jwtService;
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) {

        if (isPlatformSuperAdmin(request)) {
            // Super-admin: leave the tenant context empty. Note this does NOT
            // give ORM-level cross-org visibility — Hibernate's @TenantId
            // resolver (TenantIdentifierResolverImpl) falls back to a sentinel
            // that matches no real org when the context is empty, so
            // repository calls fail closed. Endpoints that genuinely need
            // cross-org data must use native/JDBC queries instead.
            return true;
        }

        String tenantId = resolveTenantId(request);
        if (tenantId != null) {
            try {
                Long orgId = Long.valueOf(tenantId);
                Optional<Organization> orgOpt = organizationRepository.findById(orgId);
                if (orgOpt.isPresent() && Boolean.TRUE.equals(orgOpt.get().getIsActive())) {
                    organizationContext.setCurrentOrganization(orgOpt.get());
                }
            } catch (NumberFormatException ignored) {
                // Invalid tenant ID — proceed without tenant context
            }
        }

        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request,
                                HttpServletResponse response,
                                Object handler,
                                Exception ex) {
        organizationContext.clear();
    }

    /**
     * True when the JWT Bearer token's {@code role} claim identifies the platform
     * super-admin (ADMIN role), who must see across every tenant.
     */
    private boolean isPlatformSuperAdmin(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return false;
        }
        try {
            Claims claims = jwtService.extractAllClaims(authHeader.substring(7));
            Object role = claims.get("role");
            return role != null && "ADMIN".equals(role.toString());
        } catch (Exception ignored) {
            return false;
        }
    }

    /**
     * Resolves the tenant identifier from one of four sources (priority order):
     * 1. JWT Bearer token's {@code organization_id} claim (authenticated requests)
     * 2. {@code X-Tenant-ID} request header (raw numeric org id, for API/service calls)
     * 3. {@code X-Tenant-Slug} request header (org slug, e.g. "tenant1" — sent by the
     *    admin portal's HTTP interceptor, derived from the browser's subdomain; needed
     *    because the SPA calls the backend at a fixed absolute origin (localhost:8080),
     *    so the request's own Host header can never reveal which tenant subdomain the
     *    user is actually browsing on)
     * 4. Request hostname/domain for domain-based tenancy (e.g., tenant1.localhost, acme.example.com)
     */
    private String resolveTenantId(HttpServletRequest request) {
        // 1. Try JWT Bearer token — header first, then a `token` query param.
        // The query-param fallback exists for <video src>/<img src>/<iframe src>
        // requests (e.g. /api/media/{id}/serve), which are plain browser GETs
        // that cannot attach an Authorization header at all.
        String jwt = extractBearerToken(request);
        if (jwt != null) {
            try {
                Claims claims = jwtService.extractAllClaims(jwt);
                Object orgClaim = claims.get("organization_id");
                if (orgClaim != null) {
                    return orgClaim.toString();
                }
            } catch (Exception ignored) {
                // Token invalid or expired — fall through to header check
            }
        }

        // 2. Fall back to X-Tenant-ID header
        String headerTenantId = request.getHeader("X-Tenant-ID");
        if (headerTenantId != null && !headerTenantId.isEmpty()) {
            return headerTenantId;
        }

        // 3. Fall back to X-Tenant-Slug header, or a `tenant` / `tenantSlug` / `slug` query param
        String tenantSlug = request.getHeader("X-Tenant-Slug");
        if (tenantSlug == null || tenantSlug.isEmpty()) {
            tenantSlug = request.getParameter("tenant");
        }
        if (tenantSlug == null || tenantSlug.isEmpty()) {
            tenantSlug = request.getParameter("tenantSlug");
        }
        if (tenantSlug == null || tenantSlug.isEmpty()) {
            tenantSlug = request.getParameter("slug");
        }
        if (tenantSlug != null && !tenantSlug.isEmpty()) {
            tenantSlug = tenantSlug.trim().toLowerCase();
            if (tenantSlug.startsWith("app-") && tenantSlug.length() > 4) {
                tenantSlug = tenantSlug.substring(4);
            }
            Optional<Organization> org = organizationRepository.findBySlug(tenantSlug);
            if (org.isPresent()) {
                return String.valueOf(org.get().getId());
            }
            if ("axisora".equalsIgnoreCase(tenantSlug) || "admin".equalsIgnoreCase(tenantSlug) || "www".equalsIgnoreCase(tenantSlug) || "app".equalsIgnoreCase(tenantSlug)) {
                String defaultId = findDefaultOrgId();
                if (defaultId != null) {
                    return defaultId;
                }
            }
        }

        // 4. Fall back to domain-based resolution
        return resolveTenantFromDomain(request);
    }

    /** The JWT from the Authorization header, or the `token` query param as a fallback. */
    private String extractBearerToken(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            return authHeader.substring(7);
        }
        String queryToken = request.getParameter("token");
        return (queryToken != null && !queryToken.isEmpty()) ? queryToken : null;
    }

    /**
     * Resolves tenant from the request hostname.
     * <p>
     * Domain structure:
     * <ul>
     *   <li>{@code admin.axisoraforge.in}, {@code app-admin.axisoraforge.in}, {@code app.axisoraforge.in} → default org ("axisora" / "admin")</li>
     *   <li>{@code manyasree.axisoraforge.in} → org with slug "manyasree" (Admin Portal)</li>
     *   <li>{@code app-manyasree.axisoraforge.in} → org with slug "manyasree" (Student/Mobile App)</li>
     *   <li>{@code app-[slug].axisoraforge.in} → org with slug [slug]</li>
     *   <li>{@code [slug].axisoraforge.in} → org with slug [slug]</li>
     *   <li>{@code localhost}, {@code 127.0.0.1}, bare IP → default org</li>
     * </ul>
     */
    private String resolveTenantFromDomain(HttpServletRequest request) {
        String serverName = request.getServerName();

        // Local development: always resolve to the default (axisora/admin) org
        if (serverName.startsWith("localhost")
                || serverName.startsWith("127.0.0.1")
                || serverName.matches("^\\d{1,3}(\\.\\d{1,3}){3}$")) {
            return findDefaultOrgId();
        }

        // Split the hostname into parts.
        // admin.axisoraforge.in       → ["admin", "axisoraforge", "in"]      → default org
        // app-admin.axisoraforge.in   → ["app-admin", "axisoraforge", "in"]  → default org
        // app.axisoraforge.in         → ["app", "axisoraforge", "in"]        → default org
        // manyasree.axisoraforge.in   → ["manyasree", "axisoraforge", "in"]  → manyasree org
        // app-manyasree.axisoraforge.in → ["app-manyasree", "axisoraforge", "in"] → manyasree org
        String[] parts = serverName.split("\\.");
        if (parts.length >= 3) {
            String subdomain = parts[0].toLowerCase();
            // Handle app-<slug> pattern
            if (subdomain.startsWith("app-") && subdomain.length() > 4) {
                subdomain = subdomain.substring(4);
            }
            // "www", "admin", "app", and "axisora" are platform/root portals — treat as default org
            if ("www".equalsIgnoreCase(subdomain) || "admin".equalsIgnoreCase(subdomain)
                    || "axisora".equalsIgnoreCase(subdomain) || "app".equalsIgnoreCase(subdomain)) {
                return findDefaultOrgId();
            }
            // Try to resolve subdomain as a tenant slug
            Optional<Organization> org = organizationRepository.findBySlug(subdomain);
            if (org.isPresent()) {
                return String.valueOf(org.get().getId());
            }
        }

        // Custom domain lookup (e.g., custom.school.org)
        Optional<Organization> orgByDomain = organizationRepository.findByDomain(serverName);
        if (orgByDomain.isPresent()) {
            return String.valueOf(orgByDomain.get().getId());
        }

        // Root domain (axisoraforge.in) or unrecognized host → fall back to default org.
        return findDefaultOrgId();
    }

    private String findDefaultOrgId() {
        Optional<Organization> defaultOrg = organizationRepository.findBySlug("axisora")
                .or(() -> organizationRepository.findBySlug("admin"))
                .or(() -> organizationRepository.findById(1L));
        return defaultOrg.map(org -> String.valueOf(org.getId())).orElse(null);
    }
}

