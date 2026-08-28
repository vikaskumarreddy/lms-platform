package com.institute.lms.service;

import com.institute.lms.dto.StudentStatsDTO;
import com.institute.lms.dto.PlacementMetricsDTO;
import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class StudentStatsService {

    private final UserRepository userRepository;
    private final BatchRepository batchRepository;
    private final SubscriptionPlanRepository subscriptionPlanRepository;
    private final AttendanceRepository attendanceRepository;
    private final AssignmentRepository assignmentRepository;
    private final AssignmentSubmissionRepository assignmentSubmissionRepository;
    private final ExamRepository examRepository;
    private final ExamSubmissionRepository examSubmissionRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final CourseRepository courseRepository;
    private final FeedbackRepository feedbackRepository;
    private final StudentPlacementRepository studentPlacementRepository;
    private final EventRepository eventRepository;

    public StudentStatsService(UserRepository userRepository,
                               BatchRepository batchRepository,
                               SubscriptionPlanRepository subscriptionPlanRepository,
                               AttendanceRepository attendanceRepository,
                               AssignmentRepository assignmentRepository,
                               AssignmentSubmissionRepository assignmentSubmissionRepository,
                               ExamRepository examRepository,
                               ExamSubmissionRepository examSubmissionRepository,
                               EnrollmentRepository enrollmentRepository,
                               CourseRepository courseRepository,
                               FeedbackRepository feedbackRepository,
                               StudentPlacementRepository studentPlacementRepository,
                               EventRepository eventRepository) {
        this.userRepository = userRepository;
        this.batchRepository = batchRepository;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
        this.attendanceRepository = attendanceRepository;
        this.assignmentRepository = assignmentRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.examRepository = examRepository;
        this.examSubmissionRepository = examSubmissionRepository;
        this.enrollmentRepository = enrollmentRepository;
        this.courseRepository = courseRepository;
        this.feedbackRepository = feedbackRepository;
        this.studentPlacementRepository = studentPlacementRepository;
        this.eventRepository = eventRepository;
    }

    @Transactional(readOnly = true)
    public StudentStatsDTO getStudentStats(Long studentId) {
        Optional<User> userOpt = userRepository.findById(studentId);
        if (userOpt.isEmpty() || userOpt.get().getRole() != User.UserRole.STUDENT) {
            throw new RuntimeException("Student not found");
        }

        User student = userOpt.get();
        StudentStatsDTO.StudentInfo studentInfo = buildStudentInfo(student);
        StudentStatsDTO.AttendanceStats attendanceStats = buildAttendanceStats(student);
        StudentStatsDTO.AssignmentStats assignmentStats = buildAssignmentStats(student);
        StudentStatsDTO.ExamStats examStats = buildExamStats(student);
        StudentStatsDTO.PlacementStats placementStats = buildPlacementStats(student);
        StudentStatsDTO.CourseStats courseStats = buildCourseStats(student);

        List<StudentStatsDTO.AttendanceRecord> attendanceRecords = buildAttendanceRecords(student);
        List<StudentStatsDTO.AssignmentRecord> assignmentRecords = buildAssignmentRecords(student);
        List<StudentStatsDTO.ExamRecord> examRecords = buildExamRecords(student);
        List<StudentStatsDTO.CourseRecord> courseRecords = buildCourseRecords(student);
        List<StudentStatsDTO.PlacementRecord> placementRecords = buildPlacementRecords(student);

        return new StudentStatsDTO(
                studentInfo,
                attendanceStats,
                assignmentStats,
                examStats,
                placementStats,
                courseStats,
                attendanceRecords,
                assignmentRecords,
                examRecords,
                courseRecords,
                placementRecords
        );
    }

    /**
     * Computes the placement-eligibility metrics for a student: attendance %,
     * average course completion %, average assignment score % and average exam
     * score %. These are compared against a PlacementDrive's min-criteria in
     * the mobile app to decide whether the student may apply.
     */
    @Transactional(readOnly = true)
    public PlacementMetricsDTO getPlacementMetrics(Long studentId) {
        User student = userRepository.findById(studentId)
                .orElseThrow(() -> new RuntimeException("Student not found"));
        if (student.getRole() != User.UserRole.STUDENT) {
            throw new RuntimeException("Not a student");
        }

        // Attendance percentage
        List<Attendance> attendanceList = attendanceRepository.findByUserId(studentId);
        long totalClasses = attendanceList.size();
        long attended = attendanceList.stream().filter(Attendance::getPresent).count();
        double attendancePercentage = totalClasses > 0 ? (attended * 100.0) / totalClasses : 0.0;

        // Course completion: average progress across all enrolled courses
        List<Enrollment> enrollments = enrollmentRepository.findByUserId(studentId);
        double courseCompletionPercentage = enrollments.stream()
                .mapToInt(e -> e.getProgressPercentage() != null ? e.getProgressPercentage() : 0)
                .average()
                .orElse(0.0);

        // Assignment average score as a percentage of each assignment's total marks
        double assignmentAveragePercentage = assignmentSubmissionRepository.findByUserId(studentId).stream()
                .filter(s -> Boolean.TRUE.equals(s.getIsGraded()) && s.getMarksObtained() != null)
                .mapToDouble(s -> {
                    Assignment assignment = s.getAssignmentId() != null
                            ? assignmentRepository.findById(s.getAssignmentId()).orElse(null)
                            : null;
                    if (assignment != null && assignment.getTotalMarks() != null && assignment.getTotalMarks() > 0) {
                        return (s.getMarksObtained() * 100.0) / assignment.getTotalMarks();
                    }
                    return 0.0;
                })
                .average()
                .orElse(0.0);

        // Exam average score as a percentage of each exam's total marks
        double examAveragePercentage = examSubmissionRepository.findByUserId(studentId).stream()
                .filter(s -> s.getMarksObtained() != null && Boolean.TRUE.equals(s.getIsGraded()))
                .mapToDouble(s -> {
                    Exam exam = s.getExamId() != null
                            ? examRepository.findById(s.getExamId()).orElse(null)
                            : null;
                    if (exam != null && exam.getTotalMarks() != null && exam.getTotalMarks() > 0) {
                        return (s.getMarksObtained() * 100.0) / exam.getTotalMarks();
                    }
                    return 0.0;
                })
                .average()
                .orElse(0.0);

        return new PlacementMetricsDTO(
                attendancePercentage,
                courseCompletionPercentage,
                assignmentAveragePercentage,
                examAveragePercentage
        );
    }

    private StudentStatsDTO.StudentInfo buildStudentInfo(User student) {
        String batchName = "";
        if (student.getBatchId() != null) {
            batchName = batchRepository.findById(student.getBatchId())
                    .map(Batch::getName)
                    .orElse("");
        }

        String planName = "";
        if (student.getPlanId() != null) {
            planName = subscriptionPlanRepository.findById(student.getPlanId())
                    .map(SubscriptionPlan::getName)
                    .orElse("");
        }

        return new StudentStatsDTO.StudentInfo(
                student.getId(),
                student.getName(),
                student.getEmail(),
                student.getPhone(),
                student.getBatchId(),
                batchName,
                planName
        );
    }

    private StudentStatsDTO.AttendanceStats buildAttendanceStats(User student) {
        List<Attendance> attendanceList = attendanceRepository.findByUserId(student.getId());
        long totalClasses = attendanceList.size();
        long attended = attendanceList.stream().filter(Attendance::getPresent).count();
        long missed = totalClasses - attended;
        double percentage = totalClasses > 0 ? (attended * 100.0) / totalClasses : 0.0;

        return new StudentStatsDTO.AttendanceStats(totalClasses, attended, missed, percentage);
    }

    private StudentStatsDTO.AssignmentStats buildAssignmentStats(User user) {
        // Get user's batch
        Long batchId = user.getBatchId();
        List<Assignment> allAssignments = assignmentRepository.findByIsActiveTrue();
        
        // Filter assignments for the student's batch
        List<Assignment> studentAssignments = allAssignments.stream()
                .filter(a -> a.getBatchIds() != null && a.getBatchIds().contains(batchId))
                .collect(Collectors.toList());

        long totalAssignments = studentAssignments.size();
        
        // Get submissions for this student
        List<AssignmentSubmission> submissions = assignmentSubmissionRepository.findByUserId(user.getId());
        List<Long> submittedAssignmentIds = submissions.stream()
                .map(AssignmentSubmission::getAssignmentId)
                .collect(Collectors.toList());

        long submitted = submittedAssignmentIds.size();
        long pending = totalAssignments - submitted;
        
        // Count overdue (not submitted and due date passed)
        LocalDateTime now = LocalDateTime.now();
        long overdue = studentAssignments.stream()
                .filter(a -> !submittedAssignmentIds.contains(a.getId()))
                .filter(a -> a.getDueDate() != null && a.getDueDate().isBefore(now))
                .count();

        double submissionPercentage = totalAssignments > 0 ? (submitted * 100.0) / totalAssignments : 0.0;
        
        // Calculate average marks from graded submissions
        double averageMarks = submissions.stream()
                .filter(s -> s.getIsGraded() && s.getMarksObtained() != null)
                .mapToInt(s -> s.getMarksObtained())
                .average()
                .orElse(0.0);

        return new StudentStatsDTO.AssignmentStats(
                totalAssignments, submitted, pending, overdue, submissionPercentage, averageMarks
        );
    }

    private StudentStatsDTO.ExamStats buildExamStats(User user) {
        List<ExamSubmission> examSubmissions = examSubmissionRepository.findByUserId(user.getId());
        
        long totalExams = examSubmissions.size();
        long attended = examSubmissions.stream().filter(s -> s.getSubmittedAt() != null).count();
        long passed = examSubmissions.stream()
                .filter(r -> r.getMarksObtained() != null && r.getIsGraded())
                .filter(r -> {
                    Exam exam = examRepository.findById(r.getExamId()).orElse(null);
                    return exam != null && exam.getTotalMarks() != null && 
                           (r.getMarksObtained() * 100.0 / exam.getTotalMarks()) >= 40.0;
                })
                .count();
        long failed = attended - passed;
        
        double passPercentage = attended > 0 ? (passed * 100.0) / attended : 0.0;
        
        double averageScore = examSubmissions.stream()
                .filter(s -> s.getMarksObtained() != null && s.getIsGraded())
                .mapToDouble(s -> {
                    Exam exam = examRepository.findById(s.getExamId()).orElse(null);
                    if (exam != null && exam.getTotalMarks() != null && exam.getTotalMarks() > 0) {
                        return (s.getMarksObtained() * 100.0) / exam.getTotalMarks();
                    }
                    return 0.0;
                })
                .average()
                .orElse(0.0);

        return new StudentStatsDTO.ExamStats(
                totalExams, attended, passed, failed, passPercentage, averageScore
        );
    }

    private StudentStatsDTO.PlacementStats buildPlacementStats(User user) {
        List<StudentPlacement> placements = studentPlacementRepository.findByUserId(user.getId());
        
        boolean isPlaced = placements.stream().anyMatch(p -> p.getIsPlaced() != null && p.getIsPlaced());
        
        StudentPlacement placedRecord = placements.stream()
                .filter(p -> p.getIsPlaced() != null && p.getIsPlaced())
                .findFirst()
                .orElse(null);

        int totalApplications = placements.size();
        long selected = placements.stream()
                .filter(p -> p.getStatus() == StudentPlacement.Status.SELECTED)
                .count();
        long rejected = placements.stream()
                .filter(p -> p.getStatus() == StudentPlacement.Status.REJECTED)
                .count();

        return new StudentStatsDTO.PlacementStats(
                isPlaced,
                placedRecord != null ? placedRecord.getCompanyName() : null,
                placedRecord != null ? placedRecord.getRole() : null,
                placedRecord != null ? new java.math.BigDecimal(placedRecord.getPackageAmount()) : null,
                totalApplications,
                (int) selected,
                (int) rejected
        );
    }

    private StudentStatsDTO.CourseStats buildCourseStats(User user) {
        List<Enrollment> enrollments = enrollmentRepository.findByUserId(user.getId());
        
        int totalCourses = enrollments.size();
        long completed = enrollments.stream()
                .filter(e -> e.getCompletedAt() != null)
                .count();
        long inProgress = totalCourses - completed;
        
        double averageProgress = enrollments.stream()
                .mapToInt(e -> e.getProgressPercentage() != null ? e.getProgressPercentage() : 0)
                .average()
                .orElse(0.0);
        
        // Get feedback/ratings
        List<Feedback> feedbacks = feedbackRepository.findByUserId(user.getId());
        double averageRating = feedbacks.stream()
                .filter(f -> f.getRating() != null)
                .mapToInt(f -> f.getRating())
                .average()
                .orElse(0.0);

        return new StudentStatsDTO.CourseStats(
                totalCourses, (int) completed, (int) inProgress, averageProgress, averageRating
        );
    }

    private List<StudentStatsDTO.AttendanceRecord> buildAttendanceRecords(User student) {
        List<Attendance> attendanceList = attendanceRepository.findByUserId(student.getId());
        return attendanceList.stream().map(a -> {
            String eventName = "";
            String eventType = "";
            String date = "";
            String subject = null;
            String isoDate = null;
            if (a.getEvent() != null) {
                eventName = a.getEvent().getTitle();
                eventType = a.getEvent().getEventType();
                subject = a.getEvent().getSubject();
                if (a.getEvent().getStartTime() != null) {
                    date = a.getEvent().getStartTime().format(DateTimeFormatter.ofPattern("dd MMM yyyy"));
                    isoDate = a.getEvent().getStartTime().toLocalDate().toString();
                }
            }
            return new StudentStatsDTO.AttendanceRecord(
                    a.getEvent() != null ? a.getEvent().getId() : null,
                    eventName,
                    eventType,
                    date,
                    a.getPresent() != null && a.getPresent(),
                    a.getRemarks(),
                    subject,
                    isoDate
            );
        }).collect(Collectors.toList());
    }

    private List<StudentStatsDTO.AssignmentRecord> buildAssignmentRecords(User user) {
        Long batchId = user.getBatchId();
        List<Assignment> assignments = assignmentRepository.findByIsActiveTrue().stream()
                .filter(a -> a.getBatchIds() != null && a.getBatchIds().contains(batchId))
                .collect(Collectors.toList());

        List<AssignmentSubmission> submissions = assignmentSubmissionRepository.findByUserId(user.getId());

        return assignments.stream().map(a -> {
            AssignmentSubmission submission = submissions.stream()
                    .filter(s -> s.getAssignmentId().equals(a.getId()))
                    .findFirst()
                    .orElse(null);

            String courseName = "";
            if (a.getCourseId() != null) {
                courseName = courseRepository.findById(a.getCourseId())
                        .map(Course::getTitle)
                        .orElse("");
            }

            String dueDate = "";
            if (a.getDueDate() != null) {
                dueDate = a.getDueDate().format(DateTimeFormatter.ofPattern("dd MMM yyyy"));
            }

            return new StudentStatsDTO.AssignmentRecord(
                    a.getId(),
                    a.getTitle(),
                    courseName,
                    dueDate,
                    submission != null,
                    submission != null ? submission.getMarksObtained() : null,
                    a.getTotalMarks(),
                    submission != null ? submission.getFeedback() : null,
                    submission != null && submission.getIsGraded()
            );
        }).collect(Collectors.toList());
    }

    private List<StudentStatsDTO.ExamRecord> buildExamRecords(User user) {
        List<ExamSubmission> submissions = examSubmissionRepository.findByUserId(user.getId());
        return submissions.stream().map(s -> {
            String title = "";
            String courseName = "";
            String examDate = "";
            Integer totalMarks = null;
            
            if (s.getExamId() != null) {
                Exam exam = examRepository.findById(s.getExamId()).orElse(null);
                if (exam != null) {
                    title = exam.getTitle();
                    examDate = exam.getExamDate() != null ? 
                            exam.getExamDate().format(DateTimeFormatter.ofPattern("dd MMM yyyy")) : "";
                    totalMarks = exam.getTotalMarks();
                    if (exam.getCourseId() != null) {
                        courseName = courseRepository.findById(exam.getCourseId())
                                .map(Course::getTitle)
                                .orElse("");
                    }
                }
            }

            double percentage = 0.0;
            String status = "N/A";
            if (s.getMarksObtained() != null && totalMarks != null && totalMarks > 0) {
                percentage = (s.getMarksObtained() * 100.0) / totalMarks;
                status = percentage >= 40.0 ? "Passed" : "Failed";
            }

            return new StudentStatsDTO.ExamRecord(
                    s.getExamId(),
                    title,
                    courseName,
                    examDate,
                    s.getMarksObtained(),
                    totalMarks,
                    percentage,
                    status
            );
        }).collect(Collectors.toList());
    }

    private List<StudentStatsDTO.CourseRecord> buildCourseRecords(User user) {
        List<Enrollment> enrollments = enrollmentRepository.findByUserId(user.getId());
        List<Feedback> feedbacks = feedbackRepository.findByUserId(user.getId());

        return enrollments.stream().map(e -> {
            Course course = e.getCourse();
            Feedback feedback = feedbacks.stream()
                    .filter(f -> f.getCourse() != null && f.getCourse().getId().equals(course.getId()))
                    .findFirst()
                    .orElse(null);

            return new StudentStatsDTO.CourseRecord(
                    course.getId(),
                    course.getTitle(),
                    "", // Course doesn't have a code field
                    e.getProgressPercentage() != null ? e.getProgressPercentage() : 0,
                    e.getCompletedAt() != null,
                    feedback != null ? feedback.getRating() : null,
                    feedback != null ? feedback.getComment() : null
            );
        }).collect(Collectors.toList());
    }

    private List<StudentStatsDTO.PlacementRecord> buildPlacementRecords(User user) {
        List<StudentPlacement> placements = studentPlacementRepository.findByUserId(user.getId());
        return placements.stream().map(p -> {
            String companyName = p.getCompanyName() != null ? p.getCompanyName() : "";
            String role = p.getRole() != null ? p.getRole() : "";
            java.math.BigDecimal packageAmount = p.getPackageAmount() != null ? 
                    new java.math.BigDecimal(p.getPackageAmount()) : null;
            String status = p.getStatus() != null ? p.getStatus().name() : "";
            String description = p.getDescription() != null ? p.getDescription() : "";

            return new StudentStatsDTO.PlacementRecord(
                    p.getDriveId(),
                    companyName,
                    role,
                    packageAmount,
                    status,
                    description
            );
        }).collect(Collectors.toList());
    }
}