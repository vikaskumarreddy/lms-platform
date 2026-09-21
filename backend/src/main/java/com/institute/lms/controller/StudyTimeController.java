package com.institute.lms.controller;

import com.institute.lms.entity.LessonTimeLog;
import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.StudyTimeService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Study-time capture and reporting.
 *
 * <p>The lesson player calls {@code /start} on entry and {@code /stop-active} on
 * exit; the dashboard reads {@code /summary} for the "Time Spending" trend and the
 * minutes studied this month.
 */
@RestController
@RequestMapping("/api/study-time")
public class StudyTimeController {

    private static final DateTimeFormatter MONTH_LABEL = DateTimeFormatter.ofPattern("MMM");

    private final StudyTimeService studyTimeService;
    private final UserContext userContext;
    private final UserRepository userRepository;

    public StudyTimeController(StudyTimeService studyTimeService, UserContext userContext,
                               UserRepository userRepository) {
        this.studyTimeService = studyTimeService;
        this.userContext = userContext;
        this.userRepository = userRepository;
    }

    /** Opens a study session for the logged-in user. Body: {lessonId, courseId?, source?}. */
    @PostMapping("/start")
    public ResponseEntity<Map<String, Object>> start(@RequestBody Map<String, Object> body) {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();

        LessonTimeLog log = studyTimeService.startSession(
                me,
                asLong(body.get("lessonId")),
                asLong(body.get("courseId")),
                body.get("source") instanceof String s ? s : null);
        if (log == null) return ResponseEntity.badRequest().build();

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("logId", log.getId());
        response.put("lessonId", log.getLesson() != null ? log.getLesson().getId() : null);
        response.put("courseId", log.getCourseId());
        response.put("startedAt", log.getStartedAt());
        return ResponseEntity.ok(response);
    }

    /** Closes a session by id (falls back to the caller's open session when unknown). */
    @PostMapping("/{logId}/stop")
    public ResponseEntity<Map<String, Object>> stop(@PathVariable Long logId) {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(summarizeClosedSession(studyTimeService.stopSession(me, logId)));
    }

    /**
     * Closes whichever session is still open for the caller. This is the call the
     * player makes on dispose, where the session id may not be in scope.
     */
    @PostMapping("/stop-active")
    public ResponseEntity<Map<String, Object>> stopActive() {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(summarizeClosedSession(studyTimeService.closeActiveSession(me)));
    }

    /**
     * The caller's study-time summary: totals plus a 12-month minute series for the
     * dashboard trend. Staff may pass {@code ?userId=} to read another student's.
     */
    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> summary(@RequestParam(required = false) Long userId,
                                                       @RequestParam(defaultValue = "12") int months) {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();

        User target = me;
        if (userId != null && !userId.equals(me.getId())) {
            if (!isStaff(me)) return ResponseEntity.status(403).build();
            target = userRepository.findById(userId).orElse(null);
            if (target == null) return ResponseEntity.notFound().build();
        }

        int window = Math.min(Math.max(months, 1), 36);
        List<Map<String, Object>> monthly = new ArrayList<>();
        studyTimeService.monthlyMinutes(target.getId(), window).forEach((period, minutes) -> {
            Map<String, Object> point = new LinkedHashMap<>();
            point.put("period", period);
            point.put("label", java.time.YearMonth.parse(period).format(MONTH_LABEL));
            point.put("minutes", minutes);
            monthly.add(point);
        });

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("userId", target.getId());
        response.put("totalMinutes", studyTimeService.totalMinutes(target.getId()));
        response.put("todayMinutes", studyTimeService.todayMinutes(target.getId()));
        response.put("monthMinutes", studyTimeService.minutesThisMonth(target.getId()));
        response.put("sessionCount", studyTimeService.sessionCount(target.getId()));
        response.put("monthly", monthly);
        return ResponseEntity.ok(response);
    }

    private Map<String, Object> summarizeClosedSession(LessonTimeLog log) {
        Map<String, Object> response = new LinkedHashMap<>();
        if (log == null) {
            response.put("logId", null);
            response.put("durationSeconds", 0);
            response.put("durationMinutes", 0);
            response.put("closed", false);
            return response;
        }
        int seconds = log.getDurationSeconds() == null ? 0 : log.getDurationSeconds();
        response.put("logId", log.getId());
        response.put("durationSeconds", seconds);
        response.put("durationMinutes", seconds / 60);
        response.put("closed", true);
        return response;
    }

    private boolean isStaff(User user) {
        return user.getRole() == User.UserRole.ADMIN
                || user.getRole() == User.UserRole.INSTITUTE_ADMIN
                || user.getRole() == User.UserRole.INSTRUCTOR;
    }

    private Long asLong(Object value) {
        if (value == null) return null;
        if (value instanceof Number number) return number.longValue();
        try {
            return Long.parseLong(value.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}