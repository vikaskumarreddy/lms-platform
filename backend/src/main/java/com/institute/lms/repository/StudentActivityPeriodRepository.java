package com.institute.lms.repository;

import com.institute.lms.entity.StudentActivityPeriod;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * The active-student ledger. Not tenant-scoped, because billing has to aggregate
 * across organizations.
 */
@Repository
public interface StudentActivityPeriodRepository extends JpaRepository<StudentActivityPeriod, Long> {

    Optional<StudentActivityPeriod> findByOrganizationIdAndStudentIdAndPeriodYm(
            Long organizationId, Long studentId, String periodYm);

    /** The billable active-student count for a tenant in a month. */
    long countByOrganizationIdAndPeriodYm(Long organizationId, String periodYm);

    long countByOrganizationIdAndPeriodYmAndWasOverageTrue(Long organizationId, String periodYm);

    List<StudentActivityPeriod> findByOrganizationIdAndPeriodYm(Long organizationId, String periodYm);

    /**
     * Records the activity in a single statement that is safe under concurrency.
     *
     * <p>Two requests from the same student arriving together would both find no row
     * and both insert, so this relies on the unique index
     * ({@code uk_sap_org_student_period}) and an {@code ON CONFLICT} upsert instead of
     * a read-then-write. Without it, a burst of simultaneous logins could create
     * duplicate billable rows for one student — inflating an invoice in a way the
     * customer would be right to dispute.
     *
     * <p>The activity type is appended to the JSON set only when not already present,
     * so {@code activity_types} accumulates distinct types without duplicates.
     *
     * @return rows affected; 1 whether inserted or updated
     */
    @Modifying
    @Transactional
    @Query(value = """
           INSERT INTO student_activity_period (
               organization_id, student_id, period_ym,
               first_activity_at, last_activity_at, activity_count,
               first_activity_type, activity_types, was_overage,
               created_at, updated_at)
           VALUES (
               :orgId, :studentId, :periodYm,
               NOW(), NOW(), 1,
               CAST(:activityType AS text),
               CAST(jsonb_build_array(CAST(:activityType AS text)) AS text),
               :wasOverage,
               NOW(), NOW())
           ON CONFLICT (organization_id, student_id, period_ym) DO UPDATE SET
               last_activity_at = NOW(),
               activity_count   = student_activity_period.activity_count + 1,
               activity_types   = CASE
                   WHEN CAST(student_activity_period.activity_types AS jsonb)
                            @> to_jsonb(CAST(:activityType AS text))
                       THEN student_activity_period.activity_types
                   ELSE CAST(CAST(student_activity_period.activity_types AS jsonb)
                            || to_jsonb(CAST(:activityType AS text)) AS text)
                   END,
               updated_at = NOW()
           """, nativeQuery = true)
    int recordActivity(@Param("orgId") Long orgId,
                       @Param("studentId") Long studentId,
                       @Param("periodYm") String periodYm,
                       @Param("activityType") String activityType,
                       @Param("wasOverage") boolean wasOverage);

    /** Per-month counts for a tenant, newest first — drives the usage trend on the Account page. */
    @Query(value = """
           SELECT period_ym AS periodYm, COUNT(*) AS activeStudents
           FROM student_activity_period
           WHERE organization_id = :orgId
           GROUP BY period_ym
           ORDER BY period_ym DESC
           LIMIT :months
           """, nativeQuery = true)
    List<Object[]> findMonthlyCounts(@Param("orgId") Long orgId, @Param("months") int months);

    /** Active-student counts for every tenant in a month, for the platform rollup. */
    @Query(value = """
           SELECT organization_id AS organizationId, COUNT(*) AS activeStudents
           FROM student_activity_period
           WHERE period_ym = :periodYm
           GROUP BY organization_id
           """, nativeQuery = true)
    List<Object[]> countByOrganizationForPeriod(@Param("periodYm") String periodYm);
}
