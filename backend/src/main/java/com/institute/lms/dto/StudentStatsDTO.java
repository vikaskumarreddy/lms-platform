package com.institute.lms.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class StudentStatsDTO {
    private StudentInfo student;
    private AttendanceStats attendance;
    private AssignmentStats assignments;
    private ExamStats exams;
    private PlacementStats placements;
    private CourseStats courses;
    private List<AttendanceRecord> attendanceRecords;
    private List<AssignmentRecord> assignmentRecords;
    private List<ExamRecord> examRecords;
    private List<CourseRecord> courseRecords;
    private List<PlacementRecord> placementRecords;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StudentInfo {
        private Long id;
        private String name;
        private String email;
        private String phone;
        private Long batchId;
        private String batchName;
        private String planName;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AttendanceStats {
        private long totalClasses;
        private long attended;
        private long missed;
        private double percentage;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AssignmentStats {
        private long totalAssignments;
        private long submitted;
        private long pending;
        private long overdue;
        private double submissionPercentage;
        private double averageMarks;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ExamStats {
        private long totalExams;
        private long attended_exams;
        private long passed;
        private long failed;
        private double passPercentage;
        private double averageScore;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlacementStats {
        private boolean isPlaced;
        private String companyName;
        private String role;
        private BigDecimal packageAmount;
        private int totalApplications;
        private int selected;
        private int rejected;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CourseStats {
        private int totalCourses;
        private int completed;
        private int inProgress;
        private double averageProgress;
        private double averageRating;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AttendanceRecord {
        private Long eventId;
        private String eventName;
        private String eventType;
        private String date;
        private boolean present;
        private String remarks;
        private String subject;
        /** Raw ISO date (yyyy-MM-dd), for calendar-grid bucketing — {@link #date} is a display string. */
        private String isoDate;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AssignmentRecord {
        private Long assignmentId;
        private String title;
        private String courseName;
        private String dueDate;
        private boolean submitted;
        private Integer marksObtained;
        private Integer totalMarks;
        private String feedback;
        private boolean isGraded;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ExamRecord {
        private Long examId;
        private String title;
        private String courseName;
        private String examDate;
        private Integer marksObtained;
        private Integer totalMarks;
        private double percentage;
        private String status;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CourseRecord {
        private Long courseId;
        private String courseName;
        private String courseCode;
        private int progressPercentage;
        private boolean completed;
        private Integer rating;
        private String feedback;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PlacementRecord {
        private Long driveId;
        private String companyName;
        private String role;
        private BigDecimal packageAmount;
        private String status;
        private String description;
    }
}