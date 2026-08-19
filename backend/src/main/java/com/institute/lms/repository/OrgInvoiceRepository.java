package com.institute.lms.repository;

import com.institute.lms.entity.OrgInvoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Invoices. Not tenant-scoped — like the rest of the billing schema this carries a
 * plain {@code organization_id} with no {@code @TenantId}, so the platform can
 * aggregate across tenants. A tenant reading their own invoices is scoped by the
 * explicit argument, which {@code AccountController} resolves from the caller rather
 * than trusting the request.
 */
@Repository
public interface OrgInvoiceRepository extends JpaRepository<OrgInvoice, Long> {

    List<OrgInvoice> findByOrganizationIdOrderByInvoiceDateDescIdDesc(Long organizationId);

    Optional<OrgInvoice> findByInvoiceNumber(String invoiceNumber);

    List<OrgInvoice> findByStatus(String status);

    /** Overdue and unpaid — the input to the dunning sweep. */
    @Query("""
           SELECT i FROM OrgInvoice i
           WHERE i.status IN ('ISSUED', 'PARTIALLY_PAID', 'OVERDUE')
             AND i.dueDate IS NOT NULL
             AND i.dueDate < :today
           ORDER BY i.dueDate ASC
           """)
    List<OrgInvoice> findOverdue(@Param("today") LocalDate today);

    /** Issued invoices falling due soon, for the courtesy reminder. */
    @Query("""
           SELECT i FROM OrgInvoice i
           WHERE i.status = 'ISSUED'
             AND i.dueDate BETWEEN :from AND :to
           """)
    List<OrgInvoice> findDueBetween(@Param("from") LocalDate from, @Param("to") LocalDate to);

    /** Outstanding balance for a tenant, across every unpaid invoice. */
    @Query("""
           SELECT COALESCE(SUM(i.balanceDue), 0) FROM OrgInvoice i
           WHERE i.organizationId = :orgId
             AND i.status IN ('ISSUED', 'PARTIALLY_PAID', 'OVERDUE')
           """)
    BigDecimal outstandingFor(@Param("orgId") Long orgId);

    boolean existsByOrganizationIdAndPeriodYmAndInvoiceType(
            Long organizationId, String periodYm, String invoiceType);
}
