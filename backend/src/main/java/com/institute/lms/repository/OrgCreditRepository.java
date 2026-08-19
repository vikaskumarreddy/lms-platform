package com.institute.lms.repository;

import com.institute.lms.entity.OrgCreditBalance;
import com.institute.lms.subscription.CreditType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Prepaid communication credit balances. Not tenant-scoped.
 *
 * <p>These rows are a cache over {@link OrgCreditTxnRepository}'s ledger, which is the
 * authoritative record of every grant and consumption.
 */
@Repository
public interface OrgCreditRepository extends JpaRepository<OrgCreditBalance, OrgCreditBalance.Key> {

    Optional<OrgCreditBalance> findByOrganizationIdAndCreditType(Long organizationId, CreditType creditType);

    List<OrgCreditBalance> findByOrganizationId(Long organizationId);
}
