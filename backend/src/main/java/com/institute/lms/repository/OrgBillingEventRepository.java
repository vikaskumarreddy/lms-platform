package com.institute.lms.repository;

import com.institute.lms.entity.OrgBillingEvent;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/** Append-only billing audit trail. Not tenant-scoped. */
@Repository
public interface OrgBillingEventRepository extends JpaRepository<OrgBillingEvent, Long> {

    List<OrgBillingEvent> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId, Pageable pageable);

    List<OrgBillingEvent> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);
}
