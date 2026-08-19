package com.institute.lms.repository;

import com.institute.lms.entity.OrgDunningEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/** Dunning history. Not tenant-scoped. */
@Repository
public interface OrgDunningEventRepository extends JpaRepository<OrgDunningEvent, Long> {

    List<OrgDunningEvent> findByInvoiceIdOrderByAttemptNoAsc(Long invoiceId);

    List<OrgDunningEvent> findByOrganizationIdOrderBySentAtDesc(Long organizationId);

    /** Whether a given escalation step has already fired, so nobody is chased twice. */
    boolean existsByInvoiceIdAndEventType(Long invoiceId, String eventType);

    long countByInvoiceId(Long invoiceId);
}
