package com.institute.lms.repository;

import com.institute.lms.entity.OrgPlanChangeRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Tenant-raised plan change requests awaiting platform approval. Not tenant-scoped. */
@Repository
public interface OrgPlanChangeRequestRepository extends JpaRepository<OrgPlanChangeRequest, Long> {

    /**
     * The organization's open request. A partial unique index allows only one PENDING
     * row per organization, so repeated Upgrade clicks update rather than duplicate.
     */
    Optional<OrgPlanChangeRequest> findByOrganizationIdAndStatus(Long organizationId, String status);

    List<OrgPlanChangeRequest> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);

    /** The platform team's queue, oldest first. */
    List<OrgPlanChangeRequest> findByStatusOrderByCreatedAtAsc(String status);

    long countByStatus(String status);
}
