package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * A certificate issued by the institute to a student for a completed course.
 * Rendered as a PDF on the mobile app using the institute/course/duration
 * fields set here by the admin, plus the logged-in student's own name/email.
 */
@Entity
@Table(name = "certificates")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Certificate extends BaseEntity {

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "institute_name", nullable = false)
    private String instituteName;

    @Column(name = "course_name", nullable = false)
    private String courseName;

    @Column
    private String duration;

    @Column(name = "credential_id", unique = true)
    private String credentialId;

    @Column(name = "issue_date")
    private LocalDate issueDate = LocalDate.now();
}
