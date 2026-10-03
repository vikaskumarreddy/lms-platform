package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "placement_drives")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class PlacementDrive extends BaseEntity {
    @Column(name = "company_name", nullable = false)
    private String companyName;

    /** Optional company logo image URL, shown as the drive card's header image. */
    @Column(name = "company_logo_url", length = 1000)
    private String companyLogoUrl;

    @Column(nullable = false)
    private String role;

    @Column(name = "package_amount")
    private BigDecimal packageAmount;

    private String location;

    @Column(columnDefinition = "TEXT")
    private String eligibility;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "apply_link")
    private String applyLink;

    private LocalDateTime deadline;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "plan_id")
    private Long planId;

    /**
     * INTERNAL: institute-run drive with schedulable interview slots (see
     * InterviewSlot). EXTERNAL: company-run drive, informational only --
     * students just use applyLink, no in-app scheduling.
     */
    @Column(name = "drive_type", nullable = false)
    private String driveType = "EXTERNAL";

    /**
     * Optional eligibility criteria (minimum thresholds, in percent). A student
     * is only allowed to apply if they meet every configured criterion.
     * A null criterion means that particular rule is not enforced.
     */
    @Column(name = "min_attendance_percent")
    private Double minAttendancePercent;

    @Column(name = "min_course_completion_percent")
    private Double minCourseCompletionPercent;

    @Column(name = "min_assignment_avg_percent")
    private Double minAssignmentAvgPercent;

    @Column(name = "min_exam_avg_percent")
    private Double minExamAvgPercent;

    @Column(name = "recruiter_token")
    private String recruiterToken;

    @Column(name = "assigned_faculty_id")
    private Long assignedFacultyId;

    @Column(name = "faculty_name")
    private String facultyName;

    @Column(name = "faculty_email")
    private String facultyEmail;
}
