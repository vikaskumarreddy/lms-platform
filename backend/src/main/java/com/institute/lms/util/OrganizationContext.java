package com.institute.lms.util;

import com.institute.lms.entity.Organization;
import org.springframework.stereotype.Component;

/**
 * Thread-local holder for the current tenant (Organization) in a SaaS multi-tenant
 * setup. The {@link com.institute.lms.interceptor.TenantInterceptor} populates this
 * context at the start of every request by reading the {@code organization_id} claim
 * from the JWT, or the {@code X-Tenant-ID}/{@code X-Tenant-Slug} header. Controllers
 * and services use this to scope data to the requesting tenant.
 *
 * <p>Also consumed by {@link TenantIdentifierResolverImpl} to provide the current
 * tenant id to Hibernate's {@code @TenantId} discriminator mechanism (which
 * automatically injects the tenant predicate into every query).</p>
 */
@Component
public class OrganizationContext {

    private static final ThreadLocal<Organization> currentOrg = new ThreadLocal<>();

    /** Sets the current tenant for this request thread. */
    public void setCurrentOrganization(Organization org) {
        currentOrg.set(org);
    }

    /** Returns the current tenant, or {@code null} if none is resolved. */
    public Organization getCurrentOrganization() {
        return currentOrg.get();
    }

    /** Returns the current tenant's ID, or {@code null} if none is resolved. */
    public Long getCurrentOrgId() {
        return getCurrentOrgIdStatic();
    }

    /** Clears the tenant context at the end of a request. */
    public void clear() {
        currentOrg.remove();
    }

    /**
     * Static accessor for the current tenant's ID, usable from non-Spring-managed
     * classes (e.g. {@link BaseEntity}'s {@code @PrePersist} callback) that cannot
     * have {@link OrganizationContext} injected. Backed by the same thread-local as
     * the instance methods above.
     */
    public static Long getCurrentOrgIdStatic() {
        Organization org = currentOrg.get();
        return org != null ? org.getId() : null;
    }
}
