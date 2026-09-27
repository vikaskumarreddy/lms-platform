package com.institute.lms.repository;

import com.institute.lms.entity.LessonTimeLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Study-session ledger. Everything the dashboard's "Time Spending" panel and the
 * student's own study-time summary are built from.
 */
@Repository
public interface LessonTimeLogRepository extends JpaRepository<LessonTimeLog, Long> {

    List<LessonTimeLog> findByUserIdOrderByStartedAtDesc(Long userId);

    List<LessonTimeLog> findByUserIdAndActivityDateBetweenOrderByStartedAtAsc(
            Long userId, LocalDate from, LocalDate to);

    /** The session still running for this student, if any. At most one exists (partial unique index). */
    Optional<LessonTimeLog> findFirstByUserIdAndEndedAtIsNullOrderByStartedAtDesc(Long userId);

    List<LessonTimeLog> findAllByUserIdAndEndedAtIsNullOrderByStartedAtDesc(Long userId);

    Optional<LessonTimeLog> findFirstByUserIdAndLessonIdAndEndedAtIsNullOrderByStartedAtDesc(
            Long userId, Long lessonId);

    long countByUserId(Long userId);

    /** Total recorded study seconds for a student (closed sessions only). */
    @Query("SELECT COALESCE(SUM(l.durationSeconds), 0) FROM LessonTimeLog l " +
           "WHERE l.user.id = :userId AND l.endedAt IS NOT NULL")
    long sumDurationSecondsByUserId(@Param("userId") Long userId);

    @Query("SELECT COALESCE(SUM(l.durationSeconds), 0) FROM LessonTimeLog l " +
           "WHERE l.user.id = :userId AND l.endedAt IS NOT NULL AND l.activityDate = :day")
    long sumDurationSecondsByUserIdAndDay(@Param("userId") Long userId, @Param("day") LocalDate day);

    @Query("SELECT COALESCE(SUM(l.durationSeconds), 0) FROM LessonTimeLog l " +
           "WHERE l.user.id = :userId AND l.endedAt IS NOT NULL " +
           "  AND l.activityDate BETWEEN :from AND :to")
    long sumDurationSecondsByUserIdBetween(@Param("userId") Long userId,
                                           @Param("from") LocalDate from,
                                           @Param("to") LocalDate to);

    /**
     * Minutes studied per calendar month for one student, newest month first.
     *
     * <p>Returned as {@code [periodYm, minutes]} pairs. Native SQL because the
     * grouping is on a date truncation the entity model doesn't expose.
     */
    @Query(value = """
           SELECT to_char(activity_date, 'YYYY-MM') AS periodYm,
                  COALESCE(SUM(duration_seconds), 0) / 60 AS minutes
           FROM lesson_time_log
           WHERE user_id = :userId
             AND ended_at IS NOT NULL
             AND activity_date >= :from
           GROUP BY periodYm
           ORDER BY periodYm
           """, nativeQuery = true)
    List<Object[]> findMonthlyMinutesForUser(@Param("userId") Long userId,
                                             @Param("from") LocalDate from);

    /** Study minutes per course, for the "where did my time go" breakdown. */
    @Query("SELECT l.courseId, COALESCE(SUM(l.durationSeconds), 0) FROM LessonTimeLog l " +
           "WHERE l.user.id = :userId AND l.endedAt IS NOT NULL AND l.courseId IS NOT NULL " +
           "GROUP BY l.courseId ORDER BY 2 DESC")
    List<Object[]> findMinutesByCourseForUser(@Param("userId") Long userId);

    /** Tenant rollup used by the admin dashboard: total learned minutes in a window. */
    @Query("SELECT COALESCE(SUM(l.durationSeconds), 0) FROM LessonTimeLog l " +
           "WHERE l.endedAt IS NOT NULL AND l.activityDate BETWEEN :from AND :to")
    long sumDurationSecondsInWindow(@Param("from") LocalDate from, @Param("to") LocalDate to);
}