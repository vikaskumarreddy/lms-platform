package com.institute.lms.repository;

import com.institute.lms.entity.OrgCreditNote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/** Credit notes. Not tenant-scoped. */
@Repository
public interface OrgCreditNoteRepository extends JpaRepository<OrgCreditNote, Long> {

    List<OrgCreditNote> findByOrganizationIdOrderByIssueDateDesc(Long organizationId);

    List<OrgCreditNote> findByInvoiceId(Long invoiceId);

    /** Total already credited against an invoice, so a further credit cannot exceed it. */
    @Query("SELECT COALESCE(SUM(c.total), 0) FROM OrgCreditNote c WHERE c.invoiceId = :invoiceId")
    BigDecimal totalCreditedFor(@Param("invoiceId") Long invoiceId);
}
