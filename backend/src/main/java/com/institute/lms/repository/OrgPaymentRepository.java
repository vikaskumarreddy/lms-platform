package com.institute.lms.repository;

import com.institute.lms.entity.OrgPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/** Payments received. Not tenant-scoped. */
@Repository
public interface OrgPaymentRepository extends JpaRepository<OrgPayment, Long> {

    List<OrgPayment> findByOrganizationIdOrderByPaidAtDesc(Long organizationId);

    List<OrgPayment> findByInvoiceId(Long invoiceId);

    /**
     * Total cleared against an invoice. Bounced and refunded payments are excluded, so
     * a returned cheque correctly reopens the balance rather than leaving it
     * permanently understated.
     */
    @Query("""
           SELECT COALESCE(SUM(p.amount), 0) FROM OrgPayment p
           WHERE p.invoiceId = :invoiceId
             AND p.status IN ('CLEARED', 'RECORDED')
           """)
    BigDecimal totalPaidFor(@Param("invoiceId") Long invoiceId);
}
