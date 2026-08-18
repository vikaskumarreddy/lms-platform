package com.institute.lms.entity;

import com.institute.lms.util.OrganizationContext;
import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Version;
import lombok.Data;
import org.hibernate.annotations.TenantId;
import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedBy;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * Base class for tenant-scoped entities (users, courses, exams, batches, etc.).
 *
 * <p>Every subclass automatically gets an {@code organization_id} column. The
 * {@link TenantId} annotation on {@link #organizationId} tells Hibernate's
 * DISCRIMINATOR multi-tenancy strategy to inject an {@code organization_id = ?}
 * predicate into every query — JPQL, {@code findAll()}, {@code findById()},
 * lazy collection loads, everything — so that data is always scoped to the
 * current tenant at the SQL level.
 *
 * <p>The current tenant is resolved per-request by
 * {@link com.institute.lms.interceptor.TenantInterceptor}, which populates
 * {@link OrganizationContext} (a thread-local). Hibernate's
 * {@code TenantIdentifierResolverImpl} reads that context at session-open
 * time and supplies the tenant value. Hibernate's native multi-tenancy has no
 * "unrestricted" mode — a session cannot be opened without a concrete tenant
 * identifier — so for platform super-admins (ADMIN role / no tenant context)
 * the resolver supplies a sentinel that matches no real row, meaning
 * ORM-level repository calls fail closed (return nothing) rather than seeing
 * across organizations. Genuine cross-organization admin views must query via
 * native/JDBC SQL that bypasses this entity-level filtering entirely.
 *
 * <p>{@link #stampOrganization()} auto-populates {@code organizationId} on
 * insert from the thread-local {@link OrganizationContext} so individual
 * services/controllers don't need to set it manually on every entity they
 * create — closing the gap where new tenant data could otherwise leak in
 * without a tenant tag.
 */
@Data
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @Id
    @GeneratedValue(strategy = jakarta.persistence.GenerationType.IDENTITY)
    private Long id;

    @CreatedDate
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @CreatedBy
    @Column(name = "created_by", updatable = false)
    private String createdBy;

    @LastModifiedBy
    @Column(name = "updated_by")
    private String updatedBy;

    @Version
    @Column(name = "version")
    private Long version;

    /** The tenant (organization) this row belongs to. Null only for legacy/global rows. */
    @TenantId
    @Column(name = "organization_id")
    private Long organizationId;

    /**
     * Stamps the current tenant onto this row before it is first persisted, unless
     * the caller already explicitly set an {@code organizationId} (e.g. platform
     * super-admin actions that assign data to a specific org).
     */
    @PrePersist
    protected void stampOrganization() {
        if (organizationId == null) {
            organizationId = OrganizationContext.getCurrentOrgIdStatic();
        }
    }
}