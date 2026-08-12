package com.institute.lms.controller;

import com.institute.lms.entity.Attendance;
import com.institute.lms.entity.AssignmentSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AssignmentSubmissionRepository;
import com.institute.lms.repository.AttendanceRepository;
import com.institute.lms.repository.ExamSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Lightweight weekly leaderboard: ranks students by a simple engagement
 * score (assignments submitted this week + attendance % this week),
 * replacing the old static/fake Achievements screen with something driven
 * entirely by real activity. No badges/levels -- just a clean weekly rank
 * to nudge engagement.
 */
@RestController
@RequestMapping("/api/leaderboard")
public class LeaderboardController {

    private final UserRepository userRepository;
    private final AssignmentSubmissionRepository assignmentSubmissionRepository;
    private final ExamSubmissionRepository examSubmissionRepository;
    private final AttendanceRepository attendanceRepository;

    public LeaderboardController(UserRepository userRepository,
                                  AssignmentSubmissionRepository assignmentSubmissionRepository,
                                  ExamSubmissionRepository examSubmissionRepository,
                                  AttendanceRepository attendanceRepository) {
        this.userRepository = userRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.examSubmissionRepository = examSubmissionRepository;
        this.attendanceRepository = attendanceRepository;
    }

    /**
     * Weekly leaderboard, optionally scoped to a single batch for a fair
     * same-cohort comparison. Score = (assignments submitted this week * 10)
     * + (exams submitted this week * 10) + (attendance percentage this week).
     * Returns the requesting student's own rank alongside the top entries.
     */
    @GetMapping
    public Map<String, Object> getWeeklyLeaderboard(@RequestParam(required = false) Long batchId,
                                                      @RequestParam(required = false) Long studentId) {
        LocalDateTime weekStart = LocalDateTime.now().with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY))
                .toLocalDate().atStartOfDay();

        List<User> students = userRepository.findByRole(User.UserRole.STUDENT).stream()
                .filter(u -> batchId == null || batchId.equals(u.getBatchId()))
                .toList();

        List<Map<String, Object>> entries = new java.util.ArrayList<>();
        for (User student : students) {
            long assignmentsThisWeek = assignmentSubmissionRepository.findByUserId(student.getId()).stream()
                    .filter(s -> s.getSubmittedAt() != null && s.getSubmittedAt().isAfter(weekStart))
                    .count();

            long examsThisWeek = examSubmissionRepository.findByUserId(student.getId()).stream()
                    .filter(s -> s.getSubmittedAt() != null && s.getSubmittedAt().isAfter(weekStart))
                    .count();

            List<Attendance> attendanceThisWeek = attendanceRepository.findByUserId(student.getId()).stream()
                    .filter(a -> a.getCreatedAt() != null && a.getCreatedAt().isAfter(weekStart))
                    .toList();
            long totalMarked = attendanceThisWeek.size();
            long presentCount = attendanceThisWeek.stream().filter(a -> Boolean.TRUE.equals(a.getPresent())).count();
            double attendancePercent = totalMarked > 0 ? (presentCount * 100.0 / totalMarked) : 0.0;

            double score = (assignmentsThisWeek * 10.0) + (examsThisWeek * 10.0) + attendancePercent;

            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("userId", student.getId());
            entry.put("name", student.getName());
            entry.put("assignmentsSubmitted", assignmentsThisWeek);
            entry.put("examsSubmitted", examsThisWeek);
            entry.put("attendancePercent", Math.round(attendancePercent * 100.0) / 100.0);
            entry.put("score", Math.round(score * 100.0) / 100.0);
            entries.add(entry);
        }

        entries.sort((a, b) -> Double.compare((Double) b.get("score"), (Double) a.get("score")));
        for (int i = 0; i < entries.size(); i++) {
            entries.get(i).put("rank", i + 1);
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("weekStart", weekStart.toLocalDate().toString());
        response.put("entries", entries.stream().limit(20).toList());
        if (studentId != null) {
            entries.stream()
                    .filter(e -> studentId.equals(e.get("userId")))
                    .findFirst()
                    .ifPresent(mine -> response.put("myRank", mine));
        }
        return response;
    }
}
