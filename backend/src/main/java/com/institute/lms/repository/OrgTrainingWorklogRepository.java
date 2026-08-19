package com.institute.lms.repository;

import com.institute.lms.entity.OrgTrainingWorklog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/** Delivered trainer hours. Platform-level, not tenant-scoped. */
@Repository
public interface OrgTrainingWorklogRepository extends JpaRepository<OrgTrainingWorklog, Long> {

    List<OrgTrainingWorklog> findByOrganizationIdAndPeriodYmOrderByWorkDateDesc(
            Long organizationId, String periodYm);

    List<OrgTrainingWorklog> findByAgreementIdOrderByWorkDateDesc(Long agreementId);

    /**
     * Total hours delivered in a month. This is what draws down the plan's included
     * training hours before any purchased hour is billed — the mechanism that stops
     * Managed Academy's base fee and its hourly rate charging for the same work.
     */
    @Query("""
           SELECT COALESCE(SUM(w.hours), 0) FROM OrgTrainingWorklog w
           WHERE w.organizationId = :orgId AND w.periodYm = :periodYm
           """)
    BigDecimal sumHours(@Param("orgId") Long orgId, @Param("periodYm") String periodYm);

    /** Billable hours not yet on an invoice — the input to training billing. */
    @Query("""
           SELECT w FROM OrgTrainingWorklog w
           WHERE w.organizationId = :orgId
             AND w.periodYm = :periodYm
             AND w.billable = true
             AND w.invoicedInvoiceId IS NULL
           ORDER BY w.workDate ASC
           """)
    List<OrgTrainingWorklog> findUnbilled(@Param("orgId") Long orgId, @Param("periodYm") String periodYm);
}
