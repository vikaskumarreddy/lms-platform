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
        // 1. Try JWT Bearer token
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            try {
                Claims claims = jwtService.extractAllClaims(token);
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

        // 3. Fall back to X-Tenant-Slug header (client-supplied subdomain)
        String tenantSlug = request.getHeader("X-Tenant-Slug");
        if (tenantSlug != null && !tenantSlug.isEmpty()) {
            Optional<Organization> org = organizationRepository.findBySlug(tenantSlug);
            if (org.isPresent()) {
                return String.valueOf(org.get().getId());
            }
        }

        // 4. Fall back to domain-based resolution
        return resolveTenantFromDomain(request);
    }

    /**
     * Resolves tenant from the request hostname.
     * Examples:
     *   - "localhost:4200" or "localhost:8080" → "axisora" (super admin / main platform)
     *   - "tenant1.localhost:4200" → "tenant1" (organization)
     *   - "acme.example.com" → "acme" (organization)
     */
    private String resolveTenantFromDomain(HttpServletRequest request) {
        String serverName = request.getServerName();

        // If it's localhost, it's the main platform (super admin)
        if (serverName.startsWith("localhost") || serverName.startsWith("127.0.0.1")) {
            Optional<Organization> defaultOrg = organizationRepository.findBySlug("axisora");
            return defaultOrg.map(org -> String.valueOf(org.getId())).orElse(null);
        }

        // Extract subdomain for domain-based tenancy
        // e.g., "tenant1.localhost" or "acme.example.com"
        String[] parts = serverName.split("\\.");
        if (parts.length > 1) {
            String subdomain = parts[0];
            Optional<Organization> org = organizationRepository.findBySlug(subdomain);
            if (org.isPresent()) {
                return String.valueOf(org.get().getId());
            }
        }

        // Unrecognized host (e.g. a tunnel hostname like *.ngrok-free.dev used by the
        // mobile app, or a bare IP): fall back to the default organization instead of
        // returning null. Returning null leaves the tenant context empty, and then
        // Hibernate's @TenantId discriminator injects a match-nothing sentinel into
        // every query — including the payment-info lookup in AuthService during
        // LOGIN, before any JWT exists to resolve the tenant from. That made every
        // mobile-app login report CASH / paymentRequired=false regardless of the
        // student's real payment record. The JWT's organization_id claim re-scopes
        // the tenant correctly on every authenticated request after login.
        Optional<Organization> defaultOrg = organizationRepository.findBySlug("axisora");
        return defaultOrg.map(org -> String.valueOf(org.getId())).orElse(null);
    }
}

