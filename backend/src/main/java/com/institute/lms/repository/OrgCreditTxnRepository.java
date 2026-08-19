package com.institute.lms.repository;

import com.institute.lms.entity.OrgCreditTxn;
import com.institute.lms.subscription.CreditType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * The immutable credit ledger. Every grant and consumption is a row here; the balance
 * table is derived from it, so a disputed balance can always be reconstructed.
 */
@Repository
public interface OrgCreditTxnRepository extends JpaRepository<OrgCreditTxn, Long> {

    List<OrgCreditTxn> findByOrganizationIdAndCreditTypeOrderByCreatedAtDesc(
            Long organizationId, CreditType creditType);

    List<OrgCreditTxn> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);

    /**
     * Credits consumed in a window, as a positive number. Feeds the monthly usage
     * rollup, which reports consumption rather than the signed ledger amounts.
     */
    @Query("""
           SELECT COALESCE(-SUM(t.amount), 0) FROM OrgCreditTxn t
           WHERE t.organizationId = :orgId
             AND t.creditType = :creditType
             AND t.txnType = 'CONSUMPTION'
             AND t.createdAt >= :from AND t.createdAt < :to
           """)
    long sumConsumed(@Param("orgId") Long orgId,
                     @Param("creditType") CreditType creditType,
                     @Param("from") LocalDateTime from,
                     @Param("to") LocalDateTime to);
}
