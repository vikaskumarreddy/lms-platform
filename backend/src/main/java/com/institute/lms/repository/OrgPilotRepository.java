package com.institute.lms.repository;

import com.institute.lms.entity.OrgPilot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/** Assisted pilots. Platform-level, not tenant-scoped. */
@Repository
public interface OrgPilotRepository extends JpaRepository<OrgPilot, Long> {

    /** The organization's live pilot. A partial unique index allows only one. */
    Optional<OrgPilot> findByOrganizationIdAndStatus(Long organizationId, String status);

    List<OrgPilot> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);

    List<OrgPilot> findByStatus(String status);

    /** Pilots whose decision date has passed — the conversion follow-up list. */
    List<OrgPilot> findByStatusAndDecisionDueOnBefore(String status, LocalDate date);

    /** Pilots that have run past their end date without converting. */
    List<OrgPilot> findByStatusAndEndsOnBefore(String status, LocalDate date);
}
