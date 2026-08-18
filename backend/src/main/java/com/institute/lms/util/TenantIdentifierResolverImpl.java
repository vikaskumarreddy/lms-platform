package com.institute.lms.util;

import org.hibernate.context.spi.CurrentTenantIdentifierResolver;
import org.springframework.stereotype.Component;

import java.io.Serializable;

/**
 * Resolves the current tenant (organization) id for Hibernate's
 * {@code @TenantId} DISCRIMINATOR strategy. The resolved value is injected
 * into every query as {@code organization_id = ?}.
 *
 * <p><b>Important:</b> Hibernate's native multi-tenancy has no "unrestricted /
 * see-everything" mode. {@code SessionImpl.setUpMultitenancy()} throws
 * {@code HibernateException("SessionFactory configured for multi-tenancy, but
 * no tenant identifier specified")} immediately if this method returns
 * {@code null} — for <i>every</i> session it opens, including the one Spring
 * Data JPA opens eagerly at application startup (before any HTTP request
 * exists) and any request made with no {@link OrganizationContext} set (e.g.
 * platform super-admin requests). Returning {@code null} therefore crashes
 * the app, it does not "skip" the discriminator predicate.
 *
 * <p>When there is no request-scoped org context (platform super-admin
 * requests, background threads, or app bootstrap), this falls back to a
 * sentinel value that never matches a real {@code organization_id}
 * (identity columns start at 1), so ORM-level queries made in that context
 * fail closed (return nothing) instead of crashing the session factory.
 *
 * <p>Genuine cross-organization visibility for platform super-admins (e.g.
 * {@code OrganizationController}, {@code SaasStatsController}) must be
 * implemented with native/JDBC queries that bypass Hibernate's entity-level
 * {@code @TenantId} filtering entirely — the same pattern already used by
 * the manually-scoped native queries in {@code ExamRepository} /
 * {@code AssignmentRepository} — not by relying on this resolver returning
 * {@code null}.</p>
 */
@Component
public class TenantIdentifierResolverImpl
        implements CurrentTenantIdentifierResolver {

    /** Matches no real organization row; identity columns start at 1. */
    private static final String NO_TENANT_SENTINEL = "-1";

    @Override
    public String resolveCurrentTenantIdentifier() {
        Long orgId = OrganizationContext.getCurrentOrgIdStatic();
        return orgId != null ? String.valueOf(orgId) : NO_TENANT_SENTINEL;
    }

    @Override
    public boolean validateExistingCurrentSessions() {
        return false;
    }
}
