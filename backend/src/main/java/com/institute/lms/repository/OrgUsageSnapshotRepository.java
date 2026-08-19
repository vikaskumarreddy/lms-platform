package com.institute.lms.repository;

import com.institute.lms.entity.OrgUsageSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Monthly usage rollups that invoices bill from. Not tenant-scoped. */
@Repository
public interface OrgUsageSnapshotRepository extends JpaRepository<OrgUsageSnapshot, Long> {

    Optional<OrgUsageSnapshot> findByOrganizationIdAndPeriodYm(Long organizationId, String periodYm);

    List<OrgUsageSnapshot> findByOrganizationIdOrderByPeriodYmDesc(Long organizationId);

    List<OrgUsageSnapshot> findByPeriodYm(String periodYm);

    /** Closed periods with unbilled overage — the input to overage invoicing. */
    List<OrgUsageSnapshot> findByPeriodYmAndIsFinalTrueAndOverageStudentsGreaterThan(
            String periodYm, Integer threshold);
}
