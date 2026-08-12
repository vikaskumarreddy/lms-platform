package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "batches")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Batch extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "plan_id")
    private Long planId;

    @Column(name = "start_date")
    private LocalDateTime startDate;

    @Column(name = "end_date")
    private LocalDateTime endDate;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "max_students")
    private Integer maxStudents;

    @Column(name = "schedule")
    private String schedule;

    /** The faculty/instructor mentoring this batch (links to a User with role INSTRUCTOR). */
    @Column(name = "mentor_id")
    private Long mentorId;
}