package com.institute.lms.repository;

import com.institute.lms.entity.OrgSubscription;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Platform plan catalog. {@link OrgSubscription} carries no {@code @TenantId}, so
 * these queries are safe for the super admin, whose Hibernate session runs under a
 * sentinel tenant that matches no tenant-scoped row.
 */
@Repository
public interface OrgSubscriptionRepository extends JpaRepository<OrgSubscription, Long> {

    List<OrgSubscription> findByIsActiveTrue();

    /** Preferred lookup: application logic keys off the stable code, never the display name. */
    Optional<OrgSubscription> findByCode(String code);

    boolean existsByCode(String code);

    /** Plans shown as self-serve cards on the tenant Account page, in display order. */
    List<OrgSubscription> findByIsPublicTrueAndIsActiveTrueOrderByDisplayOrderAsc();

    /** Full catalog for the platform editor, including retired and non-public plans. */
    List<OrgSubscription> findAllByOrderByDisplayOrderAscTierRankAsc();

    /**
     * Plans commercially senior to {@code tierRank} — the candidates for an upgrade.
     * Used to name a concrete upgrade target in a quota error rather than telling the
     * admin only that they have run out.
     */
    List<OrgSubscription> findByIsActiveTrueAndTierRankGreaterThanOrderByTierRankAsc(Integer tierRank);
}
