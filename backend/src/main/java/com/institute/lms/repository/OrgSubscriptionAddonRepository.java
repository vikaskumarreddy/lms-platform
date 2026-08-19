package com.institute.lms.repository;

import com.institute.lms.entity.OrgSubscriptionAddon;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/** Purchased add-ons. Not tenant-scoped — see {@link OrgSubscriptionInstanceRepository}. */
@Repository
public interface OrgSubscriptionAddonRepository extends JpaRepository<OrgSubscriptionAddon, Long> {

    List<OrgSubscriptionAddon> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);

    List<OrgSubscriptionAddon> findByOrganizationIdAndStatus(Long organizationId, String status);

    List<OrgSubscriptionAddon> findBySubscriptionInstanceIdAndStatus(Long instanceId, String status);

    /**
     * Add-ons that count towards effective limits right now: approved, started, and
     * not yet ended. Filtering the window in SQL rather than in Java keeps entitlement
     * resolution to a single query on a hot path.
     */
    @Query("""
           SELECT a FROM OrgSubscriptionAddon a
           WHERE a.organizationId = :organizationId
             AND a.status = 'ACTIVE'
             AND (a.effectiveFrom IS NULL OR a.effectiveFrom <= :now)
             AND (a.effectiveTo IS NULL OR a.effectiveTo > :now)
           """)
    List<OrgSubscriptionAddon> findEffective(@Param("organizationId") Long organizationId,
                                             @Param("now") LocalDateTime now);

    /** Pending requests awaiting a platform decision, across all tenants. */
    @Query("""
           SELECT a FROM OrgSubscriptionAddon a
           WHERE a.status IN ('PENDING_APPROVAL', 'PENDING_QUOTE')
           ORDER BY a.createdAt ASC
           """)
    List<OrgSubscriptionAddon> findAwaitingDecision();

    long countByOrganizationIdAndAddonCodeAndStatus(Long organizationId, String addonCode, String status);
}
