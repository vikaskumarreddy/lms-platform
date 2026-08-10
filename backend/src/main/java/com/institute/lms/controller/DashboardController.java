package com.institute.lms.controller;

import com.institute.lms.dto.dashboard.DashboardStatsDTO;
import com.institute.lms.dto.dashboard.RecentEnrollmentDTO;
import com.institute.lms.dto.dashboard.UpcomingEventDTO;
import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;

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

    public DashboardController(UserRepository userRepository, CourseRepository courseRepository,
                               SubscriptionRepository subscriptionRepository, SubscriptionPlanRepository subscriptionPlanRepository,
                               StudentPlacementRepository placementRepository, AssignmentRepository assignmentRepository,
                               ExamRepository examRepository, EventRepository eventRepository, EnrollmentRepository enrollmentRepository) {
        this.userRepository = userRepository;
        this.courseRepository = courseRepository;
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
        this.placementRepository = placementRepository;
        this.assignmentRepository = assignmentRepository;
        this.examRepository = examRepository;
        this.eventRepository = eventRepository;
        this.enrollmentRepository = enrollmentRepository;
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