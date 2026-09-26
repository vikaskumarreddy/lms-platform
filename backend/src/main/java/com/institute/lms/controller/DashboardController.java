package com.institute.lms.controller;

import com.institute.lms.dto.dashboard.DashboardStatsDTO;
import com.institute.lms.dto.dashboard.RecentEnrollmentDTO;
import com.institute.lms.dto.dashboard.StudentUpcomingEventDTO;
import com.institute.lms.dto.dashboard.UpcomingEventDTO;
import com.institute.lms.entity.*;
import com.institute.lms.entity.Module;
import com.institute.lms.repository.*;
import com.institute.lms.service.MentorService;
import com.institute.lms.service.StudyTimeService;
import com.institute.lms.service.subscription.EntitlementService;
import com.institute.lms.service.subscription.ResolvedEntitlements;
import com.institute.lms.service.subscription.UsageService;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.MathContext;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    /** Number of month buckets in the dashboard trend charts. */
    private static final int TREND_MONTHS = 12;

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
    private final UserContext userContext;
    private final StudentPaymentInfoRepository studentPaymentInfoRepository;
    private final BatchRepository batchRepository;
    private final CertificateRepository certificateRepository;
    private final PlacementDriveRepository placementDriveRepository;
    private final CompanyQuestionKitRepository companyQuestionKitRepository;
    private final CompanyKitFavoriteRepository companyKitFavoriteRepository;
    private final QuestionRepository questionRepository;
    private final MediaItemRepository mediaItemRepository;
    private final PdfDocumentRepository pdfDocumentRepository;
    private final PdfNoteRepository pdfNoteRepository;
    private final OrganizationRepository organizationRepository;
    private final OrganizationContext organizationContext;
    private final EntitlementService entitlementService;
    private final UsageService usageService;
    private final MentorService mentorService;
    private final StudyTimeService studyTimeService;

    public DashboardController(UserRepository userRepository, CourseRepository courseRepository,
                               SubscriptionRepository subscriptionRepository, SubscriptionPlanRepository subscriptionPlanRepository,
                               StudentPlacementRepository placementRepository, AssignmentRepository assignmentRepository,
                               ExamRepository examRepository, EventRepository eventRepository, EnrollmentRepository enrollmentRepository,
                               AttendanceRepository attendanceRepository, AssignmentSubmissionRepository assignmentSubmissionRepository,
                               ExamSubmissionRepository examSubmissionRepository, ProgressRepository progressRepository,
                               UserContext userContext, StudentPaymentInfoRepository studentPaymentInfoRepository,
                               BatchRepository batchRepository, CertificateRepository certificateRepository,
                               PlacementDriveRepository placementDriveRepository, CompanyQuestionKitRepository companyQuestionKitRepository,
                               CompanyKitFavoriteRepository companyKitFavoriteRepository, QuestionRepository questionRepository,
                               MediaItemRepository mediaItemRepository, PdfDocumentRepository pdfDocumentRepository,
                               PdfNoteRepository pdfNoteRepository,
                               OrganizationRepository organizationRepository, OrganizationContext organizationContext,
                               EntitlementService entitlementService, UsageService usageService,
                               MentorService mentorService, StudyTimeService studyTimeService) {
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
        this.userContext = userContext;
        this.studentPaymentInfoRepository = studentPaymentInfoRepository;
        this.batchRepository = batchRepository;
        this.certificateRepository = certificateRepository;
        this.placementDriveRepository = placementDriveRepository;
        this.companyQuestionKitRepository = companyQuestionKitRepository;
        this.companyKitFavoriteRepository = companyKitFavoriteRepository;
        this.questionRepository = questionRepository;
        this.mediaItemRepository = mediaItemRepository;
        this.pdfDocumentRepository = pdfDocumentRepository;
        this.pdfNoteRepository = pdfNoteRepository;
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
        this.entitlementService = entitlementService;
        this.usageService = usageService;
        this.mentorService = mentorService;
        this.studyTimeService = studyTimeService;
    }

    @GetMapping("/student/{studentId}")
    public ResponseEntity<Map<String, Object>> getStudentDashboard(@PathVariable Long studentId) {
        User user = userRepository.findById(studentId).orElse(null);
        if (user == null) return ResponseEntity.notFound().build();

        long totalEvents = attendanceRepository.countByUserId(studentId);
        long presentEvents = attendanceRepository.countByUserIdAndPresentTrue(studentId);
        double attendancePercent = totalEvents > 0 ? (presentEvents * 100.0 / totalEvents) : 0.0;

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

        // ---- trend series -------------------------------------------------
        // The dashboard's "Time Spending" chart used to render empty on every
        // device because the backend never returned a series for it. These are all
        // derived from real rows: graded marks/attendance per month, and the study
        // sessions recorded in lesson_time_log.
        List<Double> performanceTrend = buildPerformanceTrend(studentId);
        List<Long> studyMinutesTrend =
                new ArrayList<>(studyTimeService.monthlyMinutes(studentId, TREND_MONTHS).values());
        response.put("performanceTrend", performanceTrend);
        response.put("trendLabels", trendLabels(TREND_MONTHS));
        response.put("studyMinutesTrend", studyMinutesTrend);
        response.put("timeSpendingTrend", scaleToPercent(studyMinutesTrend, performanceTrend));
        response.put("totalStudyMinutes", studyTimeService.totalMinutes(studentId));
        response.put("studyMinutesThisMonth", studyTimeService.minutesThisMonth(studentId));

        // ---- mentors ------------------------------------------------------
        // Real relationships (batch mentor + course instructors), not a placeholder.
        response.put("mentors", mentorService.mentorsFor(user));

        // ---- next two events ---------------------------------------------
        response.put("upcomingEvents", upcomingEventsFor(user, 2));
        return ResponseEntity.ok(response);
    }

    /**
     * The next {@code limit} events this student is actually part of, soonest
     * first. "Part of" means the event targets their batch or plan (an event with
     * no batch/plan is a shared/all-batches event and is included for everyone).
     *
     * <p>The mobile dashboard used to pull the whole event feed and filter it on
     * the device, which made the "Upcoming" card depend on the full calendar
     * payload and gave no way for an admin surface to ask the same question.
     */
    @GetMapping("/student/{studentId}/upcoming-events")
    public ResponseEntity<List<StudentUpcomingEventDTO>> getStudentUpcomingEvents(
            @PathVariable Long studentId,
            @RequestParam(defaultValue = "2") int limit) {
        User user = userRepository.findById(studentId).orElse(null);
        if (user == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(upcomingEventsFor(user, Math.min(Math.max(limit, 1), 20)));
    }

    private List<StudentUpcomingEventDTO> upcomingEventsFor(User user, int limit) {
        LocalDateTime now = LocalDateTime.now();
        return eventRepository.findAll().stream()
                .filter(e -> e.getStartTime() != null && e.getStartTime().isAfter(now))
                .filter(e -> e.getBatchId() == null || e.getBatchId().equals(user.getBatchId()))
                .filter(e -> e.getPlanId() == null || e.getPlanId().equals(user.getPlanId()))
                .sorted(Comparator.comparing(Event::getStartTime))
                .limit(limit)
                .map(StudentUpcomingEventDTO::from)
                .collect(Collectors.toList());
    }

    /** Month keys ({@code YYYY-MM}) for the last {@code months} months, oldest first. */
    private List<String> trendLabels(int months) {
        YearMonth start = YearMonth.now().minusMonths(months - 1L);
        List<String> labels = new ArrayList<>();
        for (int i = 0; i < months; i++) {
            labels.add(start.plusMonths(i).toString());
        }
        return labels;
    }

    /**
     * Average performance (%) per month: graded assignment/exam marks where they
     * exist for that month, falling back to that month's attendance rate. A month
     * with neither is a genuine zero rather than an invented value.
     */
    private List<Double> buildPerformanceTrend(Long studentId) {
        List<String> periods = trendLabels(TREND_MONTHS);
        Map<String, Double> marksSum = new HashMap<>();
        Map<String, Integer> marksCount = new HashMap<>();
        Map<String, Integer> attendancePresent = new HashMap<>();
        Map<String, Integer> attendanceCount = new HashMap<>();

        for (AssignmentSubmission submission : assignmentSubmissionRepository.findByUserId(studentId)) {
            if (!Boolean.TRUE.equals(submission.getIsGraded()) || submission.getSubmittedAt() == null) continue;
            Assignment assignment = assignmentRepository.findById(submission.getAssignmentId()).orElse(null);
            if (assignment == null || assignment.getTotalMarks() == null || assignment.getTotalMarks() == 0
                    || submission.getMarksObtained() == null) continue;
            accumulate(marksSum, marksCount, periodOf(submission.getSubmittedAt()),
                    submission.getMarksObtained() * 100.0 / assignment.getTotalMarks());
        }
        for (ExamSubmission submission : examSubmissionRepository.findByUserId(studentId)) {
            if (!Boolean.TRUE.equals(submission.getIsGraded()) || submission.getSubmittedAt() == null) continue;
            Exam exam = examRepository.findById(submission.getExamId()).orElse(null);
            if (exam == null || exam.getTotalMarks() == null || exam.getTotalMarks() == 0
                    || submission.getMarksObtained() == null) continue;
            accumulate(marksSum, marksCount, periodOf(submission.getSubmittedAt()),
                    submission.getMarksObtained() * 100.0 / exam.getTotalMarks());
        }
        for (Attendance attendance : attendanceRepository.findByUserId(studentId)) {
            LocalDateTime when = attendance.getEvent() != null ? attendance.getEvent().getStartTime() : null;
            if (when == null) continue;
            String period = periodOf(when);
            attendanceCount.merge(period, 1, Integer::sum);
            if (Boolean.TRUE.equals(attendance.getPresent())) {
                attendancePresent.merge(period, 1, Integer::sum);
            }
        }

        List<Double> trend = new ArrayList<>();
        for (String period : periods) {
            int graded = marksCount.getOrDefault(period, 0);
            if (graded > 0) {
                trend.add(round2(marksSum.getOrDefault(period, 0.0) / graded));
                continue;
            }
            int marked = attendanceCount.getOrDefault(period, 0);
            trend.add(marked > 0 ? round2(attendancePresent.getOrDefault(period, 0) * 100.0 / marked) : 0.0);
        }
        return trend;
    }

    private void accumulate(Map<String, Double> sums, Map<String, Integer> counts,
                            String period, double value) {
        sums.merge(period, value, Double::sum);
        counts.merge(period, 1, Integer::sum);
    }

    private String periodOf(LocalDateTime when) {
        return YearMonth.from(when).toString();
    }

    /**
     * Scales a raw minute series to 0-100 against its own busiest month so it can be
     * plotted next to the percentage series. Until any study session has been
     * recorded the real performance curve is returned instead, so the chart shows
     * genuine data rather than a fabricated line.
     */
    private List<Double> scaleToPercent(List<Long> minutes, List<Double> fallback) {
        long peak = minutes.stream().mapToLong(Long::longValue).max().orElse(0L);
        if (peak <= 0L) return new ArrayList<>(fallback);
        List<Double> scaled = new ArrayList<>();
        for (Long value : minutes) {
            scaled.add(round2(value * 100.0 / peak));
        }
        return scaled;
    }

    @GetMapping("/stats")
    public ResponseEntity<DashboardStatsDTO> getDashboardStats() {
        long totalStudents;
        long activeCourses;
        BigDecimal totalRevenue;
        long placedStudents;
        double placementPercentage;
        long totalAssignments;
        long totalExams;
        long totalEvents;
        List<RecentEnrollmentDTO> enrollmentDTOs = new ArrayList<>();
        List<UpcomingEventDTO> eventDTOs = new ArrayList<>();

        if (userContext.isFaculty()) {
            // Instructor view: only data for batches/courses the instructor owns.
            Long instructorId = userContext.currentUser() != null ? userContext.currentUser().getId() : null;
            Long batchId = userContext.facultyBatchId();

            if (batchId != null) {
                totalStudents = userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batchId).size();
            } else {
                totalStudents = 0;
            }

            // Courses created by this instructor — only published ones count as "active".
            List<Course> allCourses = courseRepository.findAll();
            if (instructorId != null) {
                activeCourses = allCourses.stream()
                        .filter(c -> c.getInstructorId() != null && c.getInstructorId().equals(instructorId))
                        .filter(c -> Boolean.TRUE.equals(c.getIsPublished()))
                        .count();
            } else {
                activeCourses = 0;
            }

            // Revenue tile is hidden for instructors (no revenue data)
            totalRevenue = BigDecimal.ZERO;

            // Placements for students in the instructor's batch
            if (batchId != null) {
                List<User> batchStudents = userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batchId);
                java.util.Set<Long> studentIds = batchStudents.stream()
                        .map(User::getId)
                        .collect(Collectors.toSet());
                placedStudents = placementRepository.findByIsPlacedTrue().stream()
                        .filter(p -> p.getUser() != null && studentIds.contains(p.getUser().getId()))
                        .count();
            } else {
                placedStudents = 0;
            }
            placementPercentage = totalStudents > 0 ? (placedStudents * 100.0 / totalStudents) : 0.0;

            totalAssignments = assignmentRepository.count();
            totalExams = examRepository.count();
            totalEvents = eventRepository.count();

            // Recent enrollments — only those for the instructor's batch students
            if (batchId != null) {
                List<Enrollment> allEnrollments = enrollmentRepository.findTop5ByOrderByEnrolledAtDesc();
                if (allEnrollments != null) {
                    java.util.Set<Long> studentIds = userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batchId)
                            .stream().map(User::getId).collect(Collectors.toSet());
                    for (Enrollment enrollment : allEnrollments) {
                        if (enrollment.getUser() != null && studentIds.contains(enrollment.getUser().getId())) {
                            enrollmentDTOs.add(new RecentEnrollmentDTO(
                                enrollment.getUser().getName(),
                                enrollment.getCourse().getTitle(),
                                enrollment.getEnrolledAt() != null ? enrollment.getEnrolledAt().toString() : "",
                                enrollment.getCompletedAt() != null ? "Completed" : "Active"
                            ));
                        }
                    }
                }
            }

            List<Event> upcomingEvents = eventRepository.findTop5ByOrderByStartTimeAsc();
            if (upcomingEvents != null) {
                for (Event event : upcomingEvents) {
                    eventDTOs.add(new UpcomingEventDTO(
                        event.getTitle(),
                        event.getEventType(),
                        event.getStartTime() != null ? event.getStartTime().toString() : ""
                    ));
                }
            }
        } else {
            // Admin / Institute admin view: full platform / org-level stats
            Long orgId = organizationContext.getCurrentOrgId();
            totalStudents = orgId != null
                    ? userRepository.countStudentRecordsInOrg(orgId)
                    : userRepository.countByRole(User.UserRole.STUDENT);
            activeCourses = courseRepository.countByIsPublishedTrue();

            // Revenue = actual money collected from students (amountDue is in paise), converted to rupees.
            List<StudentPaymentInfo> payments = orgId != null
                    ? studentPaymentInfoRepository.findByOrganizationId(orgId)
                    : studentPaymentInfoRepository.findAll();
            long collectedPaise = payments.stream()
                    .filter(StudentPaymentInfo::isPaid)
                    .mapToLong(info -> info.getAmountDue() != null ? info.getAmountDue() : 0L)
                    .sum();
            totalRevenue = BigDecimal.valueOf(collectedPaise).divide(BigDecimal.valueOf(100), MathContext.DECIMAL64);

            placedStudents = placementRepository.countByIsPlacedTrue();
            placementPercentage = totalStudents > 0 ? (placedStudents * 100.0 / totalStudents) : 0.0;

            totalAssignments = assignmentRepository.count();
            totalExams = examRepository.count();
            totalEvents = eventRepository.count();

            List<Enrollment> recentEnrollments = enrollmentRepository.findTop5ByOrderByEnrolledAtDesc();
            if (recentEnrollments != null) {
                for (Enrollment enrollment : recentEnrollments) {
                    enrollmentDTOs.add(new RecentEnrollmentDTO(
                        enrollment.getUser().getName(),
                        enrollment.getCourse().getTitle(),
                        enrollment.getEnrolledAt() != null ? enrollment.getEnrolledAt().toString() : "",
                        enrollment.getCompletedAt() != null ? "Completed" : "Active"
                    ));
                }
            }

            List<Event> upcomingEvents = eventRepository.findTop5ByOrderByStartTimeAsc();
            if (upcomingEvents != null) {
                for (Event event : upcomingEvents) {
                    eventDTOs.add(new UpcomingEventDTO(
                        event.getTitle(),
                        event.getEventType(),
                        event.getStartTime() != null ? event.getStartTime().toString() : ""
                    ));
                }
            }
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

    /**
     * The enriched admin-portal dashboard: KPI cards, batch placement breakdown,
     * academic/learning progress, placement funnel, engagement and an action center.
     * Scoped exactly like {@link #getDashboardStats()} — Faculty see only their own
     * batch, everyone else (Admin / Institute Admin) sees the whole organization.
     * Subscription-usage cards are omitted for Faculty since only org admins manage
     * seats and billing.
     */
    @GetMapping("/overview")
    public ResponseEntity<Map<String, Object>> getDashboardOverview() {
        Map<String, Object> out = new LinkedHashMap<>();
        boolean faculty = userContext.isFaculty();
        Long facultyBatchId = faculty ? userContext.facultyBatchId() : null;
        Long orgId = organizationContext.getCurrentOrgId();

        List<User> allStudents = orgId != null
                ? userRepository.findByOrganizationIdAndRole(orgId, User.UserRole.STUDENT)
                : userRepository.findByRole(User.UserRole.STUDENT);
        List<User> scopedStudents = faculty
                ? allStudents.stream().filter(u -> facultyBatchId != null && facultyBatchId.equals(u.getBatchId())).toList()
                : allStudents;
        long totalStudents = scopedStudents.size();
        long activeStudents = scopedStudents.stream().filter(u -> Boolean.TRUE.equals(u.getIsActive())).count();

        List<StudentPlacement> placedRecords = placementRepository.findByIsPlacedTrue();
        java.util.Set<Long> placedUserIds = placedRecords.stream()
                .map(p -> p.getUser() != null ? p.getUser().getId() : null)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());

        List<Batch> batches = faculty
                ? (facultyBatchId != null ? batchRepository.findById(facultyBatchId).map(List::of).orElse(List.of()) : List.of())
                : batchRepository.findByIsActiveTrue();

        List<Map<String, Object>> batchBreakdown = new ArrayList<>();
        for (Batch batch : batches) {
            List<User> batchStudents = userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batch.getId());
            long placed = batchStudents.stream().filter(u -> placedUserIds.contains(u.getId())).count();
            long unplaced = batchStudents.size() - placed;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("batchId", batch.getId());
            row.put("batchName", batch.getName());
            row.put("totalStudents", batchStudents.size());
            row.put("placed", placed);
            row.put("unplaced", unplaced);
            batchBreakdown.add(row);
        }
        out.put("batchBreakdown", batchBreakdown);

        double avgAttendance = averageAttendance(scopedStudents);

        Map<String, Object> kpi = new LinkedHashMap<>();
        kpi.put("totalStudents", totalStudents);
        kpi.put("activeStudents", activeStudents);
        kpi.put("placementRate", totalStudents > 0 ? round2(placedUserIds.size() * 100.0 / totalStudents) : 0.0);
        kpi.put("averageAttendance", round2(avgAttendance));
        if (!faculty) {
            addAdminKpis(kpi);
        }
        out.put("kpi", kpi);

        out.put("academics", buildAcademics(batches));
        out.put("placements", buildPlacements(faculty, scopedStudents));
        out.put("engagement", Map.of("unansweredQuestions", questionRepository.countByIsAnsweredFalse()));
        out.put("actionCenter", buildActionCenter(scopedStudents));

        return ResponseEntity.ok(out);
    }

    private double averageAttendance(List<User> students) {
        if (students.isEmpty()) return 0.0;
        double sum = 0;
        int counted = 0;
        for (User s : students) {
            long total = attendanceRepository.countByUserId(s.getId());
            if (total == 0) continue;
            sum += (attendanceRepository.countByUserIdAndPresentTrue(s.getId()) * 100.0 / total);
            counted++;
        }
        return counted > 0 ? sum / counted : 0.0;
    }

    private double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    /** Faculty/staff counts, revenue, subscription usage and storage — admin-only KPIs. */
    private void addAdminKpis(Map<String, Object> kpi) {
        Long orgId = organizationContext.getCurrentOrgId();
        long totalFaculty = orgId != null ? userRepository.countFacultySeatsInOrg(orgId) : userRepository.countByRole(User.UserRole.INSTRUCTOR);
        long activeSubscriptions = orgId != null
                ? subscriptionRepository.countByOrganizationIdAndStatus(orgId, "ACTIVE")
                : subscriptionRepository.countByStatus("ACTIVE");

        List<StudentPaymentInfo> payments = orgId != null
                ? studentPaymentInfoRepository.findByOrganizationId(orgId)
                : studentPaymentInfoRepository.findAll();
        long collectedPaise = payments.stream()
                .filter(StudentPaymentInfo::isPaid)
                .mapToLong(info -> info.getAmountDue() != null ? info.getAmountDue() : 0L)
                .sum();
        BigDecimal monthlyRevenue = BigDecimal.valueOf(collectedPaise).divide(BigDecimal.valueOf(100), MathContext.DECIMAL64);

        long outstandingPaise = payments.stream()
                .filter(StudentPaymentInfo::isPaymentDue)
                .mapToLong(info -> info.getAmountDue() != null ? info.getAmountDue() : 0L)
                .sum();
        BigDecimal outstandingDues = BigDecimal.valueOf(outstandingPaise).divide(BigDecimal.valueOf(100), MathContext.DECIMAL64);

        Map<String, Long> revenueByMode = payments.stream()
                .filter(StudentPaymentInfo::isPaid)
                .collect(Collectors.groupingBy(
                        info -> info.getPaymentMethod() != null ? info.getPaymentMethod() : "UNKNOWN",
                        Collectors.summingLong(info -> info.getAmountDue() != null ? info.getAmountDue() / 100 : 0L)));

        kpi.put("totalFaculty", totalFaculty);
        kpi.put("activeSubscriptions", activeSubscriptions);
        kpi.put("monthlyRevenue", monthlyRevenue.setScale(2, RoundingMode.HALF_UP));
        kpi.put("outstandingDues", outstandingDues.setScale(2, RoundingMode.HALF_UP));
        kpi.put("revenueByMode", revenueByMode);

        ResolvedEntitlements resolved = entitlementService.resolve(orgId);
        Map<String, Object> quotas = new LinkedHashMap<>();
        quotas.put("maxStudents", resolved.limit(LimitKey.MAX_ACTIVE_STUDENTS));
        quotas.put("maxFaculty", resolved.limit(LimitKey.MAX_FACULTY_ACCOUNTS));
        quotas.put("storageGbLimit", resolved.limit(LimitKey.STORAGE_GB));
        quotas.put("storageGbUsed", usageService.storageGbDouble(orgId));
        long billableStudents = usageService.activeStudents(orgId);
        long recordStudents = orgId != null ? userRepository.countStudentRecordsInOrg(orgId) : 0;
        quotas.put("activeStudentsUsed", Math.max(billableStudents, recordStudents));
        quotas.put("facultyUsed", usageService.facultySeats(orgId));
        kpi.put("subscriptionQuotas", quotas);

        long videoBytes = orgId != null ? mediaItemRepository.sumStoredSizeByOrgIdAndMediaType(orgId, "video") : mediaItemRepository.sumStoredSizeByMediaType("video");
        long fileBytes = orgId != null ? mediaItemRepository.sumStoredSizeByOrgIdAndMediaType(orgId, "file") : mediaItemRepository.sumStoredSizeByMediaType("file");
        long pdfDocBytes = orgId != null ? pdfDocumentRepository.sumStoredSizeByOrgId(orgId) : pdfDocumentRepository.sumStoredSize();
        long pdfNoteBytes = orgId != null ? pdfNoteRepository.sumStoredSizeByOrgId(orgId) : pdfNoteRepository.sumStoredSize();
        long totalPdfBytes = pdfDocBytes + pdfNoteBytes;

        Map<String, Object> storage = new LinkedHashMap<>();
        storage.put("videoBytes", videoBytes);
        storage.put("fileBytes", fileBytes);
        storage.put("pdfBytes", totalPdfBytes);
        storage.put("totalBytes", videoBytes + fileBytes + totalPdfBytes);
        kpi.put("storageBreakdown", storage);
    }

    /** Certificates, grading completion and per-batch health (mentor, attendance). */
    private Map<String, Object> buildAcademics(List<Batch> batches) {
        Map<String, Object> academics = new LinkedHashMap<>();
        academics.put("assignmentsGraded", assignmentSubmissionRepository.countByIsGradedTrue());
        academics.put("assignmentsPending", assignmentSubmissionRepository.countByIsGradedFalse());
        academics.put("examsGraded", examSubmissionRepository.countByIsGradedTrue());
        academics.put("examsPending", examSubmissionRepository.countByIsGradedFalse());
        academics.put("certificatesIssued", certificateRepository.count());
        academics.put("recentCertificates", certificateRepository.findTop5ByOrderByIssueDateDesc());

        List<Map<String, Object>> batchHealth = new ArrayList<>();
        for (Batch batch : batches) {
            List<User> batchStudents = userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batch.getId());
            double batchAttendance = averageAttendance(batchStudents);
            String mentorName = batch.getMentorId() != null
                    ? userRepository.findById(batch.getMentorId()).map(User::getName).orElse(null)
                    : null;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("batchId", batch.getId());
            row.put("batchName", batch.getName());
            row.put("mentorName", mentorName);
            row.put("studentCount", batchStudents.size());
            row.put("averageAttendance", round2(batchAttendance));
            row.put("isActive", batch.getIsActive());
            batchHealth.add(row);
        }
        academics.put("batchHealth", batchHealth);
        return academics;
    }

    /** Placement funnel (eligible/in-process/placed), upcoming drives, company kit list. */
    private Map<String, Object> buildPlacements(boolean faculty, List<User> scopedStudents) {
        Map<String, Object> placements = new LinkedHashMap<>();
        java.util.Set<Long> scopedIds = scopedStudents.stream().map(User::getId).collect(Collectors.toSet());
        List<StudentPlacement> scopedPlacements = faculty
                ? placementRepository.findAll().stream()
                    .filter(p -> p.getUser() != null && scopedIds.contains(p.getUser().getId()))
                    .toList()
                : placementRepository.findAll();

        long eligible = scopedStudents.size();
        long inProcess = scopedPlacements.stream().filter(p -> p.getStatus() == StudentPlacement.Status.APPLIED).count();
        long placed = scopedPlacements.stream().filter(p -> Boolean.TRUE.equals(p.getIsPlaced())).count();
        placements.put("eligible", eligible);
        placements.put("inProcess", inProcess);
        placements.put("placed", placed);

        List<PlacementDrive> upcomingDrives = placementDriveRepository.findByIsActiveTrueOrderByDeadlineAsc().stream()
                .filter(d -> d.getDeadline() == null || d.getDeadline().isAfter(LocalDateTime.now()))
                .limit(5)
                .toList();
        placements.put("upcomingDrives", upcomingDrives);

        List<CompanyQuestionKit> kits = companyQuestionKitRepository.findByIsPublishedTrueOrderByCompanyNameAsc();
        placements.put("companyKitEngagement", kits.stream().map(k -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("kitId", k.getId());
            row.put("companyName", k.getCompanyName());
            return row;
        }).limit(10).toList());
        return placements;
    }

    /** Pending grading and low-attendance alerts. */
    private Map<String, Object> buildActionCenter(List<User> scopedStudents) {
        Map<String, Object> actionCenter = new LinkedHashMap<>();
        actionCenter.put("pendingGrading",
                assignmentSubmissionRepository.countByIsGradedFalse() + examSubmissionRepository.countByIsGradedFalse());

        long lowAttendanceCount = 0;
        for (User s : scopedStudents) {
            long total = attendanceRepository.countByUserId(s.getId());
            if (total == 0) continue;
            double pct = attendanceRepository.countByUserIdAndPresentTrue(s.getId()) * 100.0 / total;
            if (pct < 75.0) lowAttendanceCount++;
        }
        actionCenter.put("lowAttendanceCount", lowAttendanceCount);
        return actionCenter;
    }
}
