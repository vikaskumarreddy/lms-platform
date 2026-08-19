package com.institute.lms.repository;

import com.institute.lms.entity.OrgSubscriptionInstance;
import com.institute.lms.subscription.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Subscription terms. Not tenant-scoped (no {@code @TenantId}), so the platform super
 * admin can read across organizations — which is required, since the sweep jobs and
 * the organizations list both need every tenant at once.
 */
@Repository
public interface OrgSubscriptionInstanceRepository extends JpaRepository<OrgSubscriptionInstance, Long> {

    /** The tenant's live term. A partial unique index guarantees at most one. */
    Optional<OrgSubscriptionInstance> findByOrganizationIdAndIsCurrentTrue(Long organizationId);

    /** Full history for the Account page's billing timeline, newest first. */
    List<OrgSubscriptionInstance> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);

    List<OrgSubscriptionInstance> findByIsCurrentTrue();

    List<OrgSubscriptionInstance> findByIsCurrentTrueAndStatusIn(List<SubscriptionStatus> statuses);

    /**
     * Current terms whose paid period has elapsed but which are still marked as a
     * live status — the input to the scheduled expiry sweep.
     */
    @Query("""
           SELECT i FROM OrgSubscriptionInstance i
           WHERE i.isCurrent = true
             AND i.periodEnd IS NOT NULL
             AND i.periodEnd < :now
             AND i.status IN :liveStatuses
           """)
    List<OrgSubscriptionInstance> findDueForExpiry(@Param("now") LocalDateTime now,
                                                   @Param("liveStatuses") List<SubscriptionStatus> liveStatuses);

    /** Terms whose grace window has elapsed and which should drop to read-only. */
    @Query("""
           SELECT i FROM OrgSubscriptionInstance i
           WHERE i.isCurrent = true
             AND i.graceEndsAt IS NOT NULL
             AND i.graceEndsAt < :now
             AND i.status = :graceStatus
           """)
    List<OrgSubscriptionInstance> findGraceElapsed(@Param("now") LocalDateTime now,
                                                   @Param("graceStatus") SubscriptionStatus graceStatus);

    /** Terms ending soon, for renewal reminders. */
    @Query("""
           SELECT i FROM OrgSubscriptionInstance i
           WHERE i.isCurrent = true
             AND i.periodEnd IS NOT NULL
             AND i.periodEnd BETWEEN :from AND :to
             AND i.status = :status
           """)
    List<OrgSubscriptionInstance> findExpiringBetween(@Param("from") LocalDateTime from,
                                                      @Param("to") LocalDateTime to,
                                                      @Param("status") SubscriptionStatus status);

    /**
     * Clears the current flag for an organization before a replacement term is
     * inserted. Done as a bulk update so the partial unique index
     * ({@code uk_osi_current_per_org}) is never transiently violated by two current
     * rows existing at once within the same transaction.
     */
    @Modifying
    @Query("UPDATE OrgSubscriptionInstance i SET i.isCurrent = false, i.updatedAt = CURRENT_TIMESTAMP "
            + "WHERE i.organizationId = :organizationId AND i.isCurrent = true")
    int clearCurrentFlag(@Param("organizationId") Long organizationId);

    long countByIsCurrentTrueAndStatus(SubscriptionStatus status);

    long countByPlanCodeAndIsCurrentTrue(String planCode);
}
