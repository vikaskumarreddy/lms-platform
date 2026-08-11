package com.institute.lms.controller;

import com.institute.lms.dto.dashboard.DashboardStatsDTO;
import com.institute.lms.dto.dashboard.RecentEnrollmentDTO;
import com.institute.lms.dto.dashboard.UpcomingEventDTO;
import com.institute.lms.entity.*;
import com.institute.lms.entity.Module;
import com.institute.lms.repository.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    private final UserRepository userRepository;
    private final CourseRepository courseRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionPlanRepository subscriptionPlanRepository;
    private final StudentPlacementRepository placementRepository;
    private final AssignmentRepository assignmentRepository;
    private final ExamRepository examRepository;
    private final EventRepository eventRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final AttendanceRepository attendanceRepository;
    private final AssignmentSubmissionRepository assignmentSubmissionRepository;
    private final ExamSubmissionRepository examSubmissionRepository;
    private final ProgressRepository progressRepository;

    public DashboardController(UserRepository userRepository, CourseRepository courseRepository,
                               SubscriptionRepository subscriptionRepository, SubscriptionPlanRepository subscriptionPlanRepository,
                               StudentPlacementRepository placementRepository, AssignmentRepository assignmentRepository,
                               ExamRepository examRepository, EventRepository eventRepository, EnrollmentRepository enrollmentRepository,
                               AttendanceRepository attendanceRepository, AssignmentSubmissionRepository assignmentSubmissionRepository,
                               ExamSubmissionRepository examSubmissionRepository, ProgressRepository progressRepository) {
        this.userRepository = userRepository;
        this.courseRepository = courseRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
        this.placementRepository = placementRepository;
        this.assignmentRepository = assignmentRepository;
        this.examRepository = examRepository;
        this.eventRepository = eventRepository;
        this.enrollmentRepository = enrollmentRepository;
        this.attendanceRepository = attendanceRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.examSubmissionRepository = examSubmissionRepository;
        this.progressRepository = progressRepository;
    }

    /**
     * Student-facing dashboard tiles: attendance % (from marked events),
     * course progress % (based on subscribed plan's courses), and performance %
     * (graded assignments + exams marks obtained vs total marks available).
     */
    @GetMapping("/student/{studentId}")
    public ResponseEntity<Map<String, Object>> getStudentDashboard(@PathVariable Long studentId) {
        User user = userRepository.findById(studentId).orElse(null);
        if (user == null) return ResponseEntity.notFound().build();

        // Attendance %
        long totalEvents = attendanceRepository.countByUserId(studentId);
        long presentEvents = attendanceRepository.countByUserIdAndPresentTrue(studentId);
        double attendancePercent = totalEvents > 0 ? (presentEvents * 100.0 / totalEvents) : 0.0;

        // Course progress % (courses matching the student's active plan), computed from
        // actual lesson completion records rather than the courses' transient fields
        // (which are only populated by CourseServiceImpl.findAll(), not this direct repo call).
        List<Course> courses = courseRepository.findAll();
        List<Course> relevantCourses = courses.stream()
                .filter(c -> c.getPlanId() == null || c.getPlanId().equals(user.getPlanId()))
                .toList();
        java.util.Set<Long> completedLessonIds = progressRepository.findCompletedLessonIdsByUserId(studentId);
        int totalLessons = 0;
        int completedLessons = 0;
        for (Course course : relevantCourses) {
            if (course.getModules() == null) continue;
            for (Module module : course.getModules()) {
                if (module.getLessons() == null) continue;
                totalLessons += module.getLessons().size();
                completedLessons += (int) module.getLessons().stream()
                        .filter(l -> completedLessonIds.contains(l.getId()))
                        .count();
            }
        }
        double progressPercent = totalLessons > 0 ? (completedLessons * 100.0 / totalLessons) : 0.0;

        // Performance % = graded marks obtained / total marks available for graded assignments+exams
        List<AssignmentSubmission> assignmentSubs = assignmentSubmissionRepository.findByUserId(studentId).stream()
                .filter(s -> Boolean.TRUE.equals(s.getIsGraded())).toList();
        List<ExamSubmission> examSubs = examSubmissionRepository.findByUserId(studentId).stream()
                .filter(s -> Boolean.TRUE.equals(s.getIsGraded())).toList();

        int obtained = 0;
        int total = 0;
        for (AssignmentSubmission sub : assignmentSubs) {
            Assignment assignment = assignmentRepository.findById(sub.getAssignmentId()).orElse(null);
            if (assignment != null && assignment.getTotalMarks() != null) {
                obtained += sub.getMarksObtained() != null ? sub.getMarksObtained() : 0;
                total += assignment.getTotalMarks();
            }
        }
        for (ExamSubmission sub : examSubs) {
            Exam exam = examRepository.findById(sub.getExamId()).orElse(null);
            if (exam != null && exam.getTotalMarks() != null) {
                obtained += sub.getMarksObtained() != null ? sub.getMarksObtained() : 0;
                total += exam.getTotalMarks();
            }
        }
        double performancePercent = total > 0 ? (obtained * 100.0 / total) : 0.0;

        Map<String, Object> response = new java.util.LinkedHashMap<>();
        response.put("attendancePercent", Math.round(attendancePercent * 100.0) / 100.0);
        response.put("presentEvents", presentEvents);
        response.put("totalEvents", totalEvents);
        response.put("progressPercent", Math.round(progressPercent * 100.0) / 100.0);
        response.put("totalLessons", totalLessons);
        response.put("completedLessons", completedLessons);
        response.put("performancePercent", Math.round(performancePercent * 100.0) / 100.0);
        response.put("marksObtained", obtained);
        response.put("totalMarks", total);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/stats")
    public ResponseEntity<DashboardStatsDTO> getDashboardStats() {
        long totalStudents = userRepository.countByRole(User.UserRole.STUDENT);
        long activeCourses = courseRepository.countByIsPublishedTrue();
        
        // Calculate revenue: sum of all subscription plan prices for active subscriptions
        BigDecimal totalRevenue = BigDecimal.ZERO;
        List<Subscription> activeSubscriptions = subscriptionRepository.findAll();
        for (Subscription subscription : activeSubscriptions) {
            if (subscription.getPlan() != null && subscription.getPlan().getPrice() != null) {
                totalRevenue = totalRevenue.add(subscription.getPlan().getPrice());
            }
        }
        
        long placedStudents = placementRepository.countByIsPlacedTrue();
        double placementPercentage = totalStudents > 0 ? (placedStudents * 100.0 / totalStudents) : 0.0;
        
        long totalAssignments = assignmentRepository.count();
        long totalExams = examRepository.count();
        long totalEvents = eventRepository.count();
        
        // Recent enrollments (last 5)
        List<Enrollment> recentEnrollments = enrollmentRepository.findTop5ByOrderByEnrolledAtDesc();
        if (recentEnrollments == null) recentEnrollments = new ArrayList<>();
        List<RecentEnrollmentDTO> enrollmentDTOs = new ArrayList<>();
        for (Enrollment enrollment : recentEnrollments) {
            RecentEnrollmentDTO dto = new RecentEnrollmentDTO(
                enrollment.getUser().getName(),
                enrollment.getCourse().getTitle(),
                enrollment.getEnrolledAt() != null ? enrollment.getEnrolledAt().toString() : "",
                enrollment.getCompletedAt() != null ? "Completed" : "Active"
            );
            enrollmentDTOs.add(dto);
        }
        
        // Upcoming events (next 5)
        List<Event> upcomingEvents = eventRepository.findTop5ByOrderByStartTimeAsc();
        if (upcomingEvents == null) upcomingEvents = new ArrayList<>();
        List<UpcomingEventDTO> eventDTOs = new ArrayList<>();
        for (Event event : upcomingEvents) {
            UpcomingEventDTO dto = new UpcomingEventDTO(
                event.getTitle(),
                event.getEventType(),
                event.getStartTime() != null ? event.getStartTime().toString() : ""
            );
            eventDTOs.add(dto);
        }
        
        DashboardStatsDTO stats = new DashboardStatsDTO(
            totalStudents,
            activeCourses,
            totalRevenue.setScale(2, RoundingMode.HALF_UP),
            placedStudents,
            Math.round(placementPercentage * 100.0) / 100.0,
            totalAssignments,
            totalExams,
            totalEvents,
            enrollmentDTOs,
            eventDTOs
        );
        
        return ResponseEntity.ok(stats);
    }
}