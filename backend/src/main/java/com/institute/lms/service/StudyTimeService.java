package com.institute.lms.service;

import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.LessonTimeLog;
import com.institute.lms.entity.User;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.repository.LessonTimeLogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Records and reports study time per lesson.
 *
 * <p>Before this existed, the platform could say a lesson was completed but never
 * how long it took, so the dashboard had no "Time Spending" series to draw and no
 * minutes to show anywhere.
 *
 * <p>Sessions are opened by the lesson player and closed when it is left. Two
 * safety rules keep the ledger honest rather than flattering:
 * <ul>
 *   <li>a session is capped at {@link #MAX_SESSION_SECONDS}, so a client that is
 *       killed mid-lesson (leaving the row open) can't later record a whole day; and</li>
 *   <li>starting a new session closes the previous open one for that student, so
 *       opening two players can never accrue overlapping time.</li>
 * </ul>
 */
@Service
public class StudyTimeService {

    /** Upper bound on a single session, so an abandoned open row can't record hours. */
    private static final long MAX_SESSION_SECONDS = 6 * 60 * 60;

    private final LessonTimeLogRepository timeLogRepository;
    private final LessonRepository lessonRepository;

    public StudyTimeService(LessonTimeLogRepository timeLogRepository,
                            LessonRepository lessonRepository) {
        this.timeLogRepository = timeLogRepository;
        this.lessonRepository = lessonRepository;
    }

    /**
     * Opens a study session. Any session still running for this student is closed
     * first, so the ledger never contains two overlapping sessions.
     */
    @Transactional
    public LessonTimeLog startSession(User user, Long lessonId, Long courseId, String source) {
        if (user == null) return null;
        closeActiveSession(user);

        Lesson lesson = lessonId != null ? lessonRepository.findById(lessonId).orElse(null) : null;
        LessonTimeLog log = new LessonTimeLog();
        log.setUser(user);
        log.setLesson(lesson);
        log.setCourseId(courseId != null ? courseId : resolveCourseId(lesson));
        log.setSource(source == null || source.isBlank() ? "LESSON" : source);
        log.setStartedAt(LocalDateTime.now());
        log.setActivityDate(LocalDate.now());
        log.setDurationSeconds(0);
        return timeLogRepository.save(log);
    }

    /**
     * Closes the given session, or the student's open session when the id is
     * unknown (the player's dispose path can't always know the id it was given).
     */
    @Transactional
    public LessonTimeLog stopSession(User user, Long logId) {
        if (user == null) return null;

        LessonTimeLog log = null;
        if (logId != null) {
            log = timeLogRepository.findById(logId)
                    .filter(entry -> entry.getUser() != null
                            && entry.getUser().getId().equals(user.getId()))
                    .orElse(null);
        }
        if (log == null) {
            log = timeLogRepository.findFirstByUserIdAndEndedAtIsNullOrderByStartedAtDesc(user.getId()).orElse(null);
        }
        if (log == null) return null;
        return close(log);
    }

    /** Closes whatever session is currently open for this student, if any. */
    @Transactional
    public LessonTimeLog closeActiveSession(User user) {
        if (user == null) return null;
        Optional<LessonTimeLog> open =
                timeLogRepository.findFirstByUserIdAndEndedAtIsNullOrderByStartedAtDesc(user.getId());
        return open.map(this::close).orElse(null);
    }

    private LessonTimeLog close(LessonTimeLog log) {
        LocalDateTime now = LocalDateTime.now();
        long seconds = Duration.between(log.getStartedAt(), now).getSeconds();
        if (seconds < 0) seconds = 0;
        if (seconds > MAX_SESSION_SECONDS) seconds = MAX_SESSION_SECONDS;
        log.setEndedAt(now);
        log.setDurationSeconds((int) seconds);
        return timeLogRepository.save(log);
    }

    /**
     * The lesson's course, resolved through module → course. Denormalised onto the
     * session so course-level study time survives the lesson being deleted.
     */
    private Long resolveCourseId(Lesson lesson) {
        if (lesson == null || lesson.getModule() == null || lesson.getModule().getCourse() == null) return null;
        return lesson.getModule().getCourse().getId();
    }

    // ------------------------------------------------------------------ reporting

    public long totalMinutes(Long userId) {
        return timeLogRepository.sumDurationSecondsByUserId(userId) / 60;
    }

    public long todayMinutes(Long userId) {
        return timeLogRepository.sumDurationSecondsByUserIdAndDay(userId, LocalDate.now()) / 60;
    }

    public long minutesThisMonth(Long userId) {
        YearMonth now = YearMonth.now();
        return timeLogRepository.sumDurationSecondsByUserIdBetween(
                userId, now.atDay(1), now.atEndOfMonth()) / 60;
    }

    public long sessionCount(Long userId) {
        return timeLogRepository.countByUserId(userId);
    }

    /**
     * Minutes studied per month for the last {@code months} months, oldest first,
     * including months with no activity as zero. Fixed-length and gap-filled
     * because a trend chart must not silently compress empty months.
     */
    public Map<String, Long> monthlyMinutes(Long userId, int months) {
        YearMonth start = YearMonth.now().minusMonths(Math.max(0, months - 1L));
        Map<String, Long> byPeriod = new LinkedHashMap<>();
        for (int i = 0; i < months; i++) {
            byPeriod.put(start.plusMonths(i).toString(), 0L);
        }
        for (Object[] row : timeLogRepository.findMonthlyMinutesForUser(userId, start.atDay(1))) {
            String period = row[0] == null ? null : row[0].toString();
            if (period == null || !byPeriod.containsKey(period)) continue;
            byPeriod.put(period, row[1] == null ? 0L : ((Number) row[1]).longValue());
        }
        return byPeriod;
    }

    /** Study minutes per course id, largest total first. */
    public Map<Long, Long> minutesByCourse(Long userId) {
        Map<Long, Long> byCourse = new LinkedHashMap<>();
        for (Object[] row : timeLogRepository.findMinutesByCourseForUser(userId)) {
            if (row[0] == null) continue;
            byCourse.put(((Number) row[0]).longValue(),
                    row[1] == null ? 0L : ((Number) row[1]).longValue() / 60);
        }
        return byCourse;
    }

    /** The raw ledger, newest first. */
    public List<LessonTimeLog> recentSessions(Long userId) {
        return timeLogRepository.findByUserIdOrderByStartedAtDesc(userId);
    }
}