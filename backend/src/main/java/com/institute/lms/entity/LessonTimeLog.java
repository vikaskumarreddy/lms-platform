package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * One recorded study session: the time a student actually spent inside a
 * lesson.
 *
 * <p>This is the missing input behind the dashboard's "Time Spending" panel —
 * progress told us <em>whether</em> a lesson was finished, never <em>how long</em>
 * it took, so there was no trend to plot.
 *
 * <p>A row is opened when the lesson player starts ({@code endedAt == null}) and
 * closed when the student leaves. If the client never closes it (app killed,
 * crash, lost network) the server closes it on the next session and clamps the
 * duration, so an abandoned session cannot record hours that were never spent.
 * A partial unique index ({@code uk_lesson_time_log_open_session}) enforces at
 * most one open session per student, which is what makes that recovery sound.
 */
@Entity
@Table(name = "lesson_time_log")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = {"user", "lesson"})
public class LessonTimeLog extends BaseEntity {

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    @JsonIgnore
    private User user;

    /** The lesson being studied. Nullable: the lesson may be deleted without erasing history. */
    @ManyToOne
    @JoinColumn(name = "lesson_id")
    @JsonIgnore
    private Lesson lesson;

    /** Denormalised course id so course-level study time survives lesson deletion. */
    @Column(name = "course_id")
    private Long courseId;

    /** Which activity consumed the time: LESSON, PDF, QUIZ ... */
    @Column(name = "source", length = 20)
    private String source = "LESSON";

    @Column(name = "started_at", nullable = false)
    private LocalDateTime startedAt;

    /** Null while the session is still running. */
    @Column(name = "ended_at")
    private LocalDateTime endedAt;

    @Column(name = "duration_seconds")
    private Integer durationSeconds = 0;

    /** Calendar day the session started on, kept separately for cheap monthly rollups. */
    @Column(name = "activity_date", nullable = false)
    private LocalDate activityDate;

    public boolean isOpen() {
        return endedAt == null;
    }
}