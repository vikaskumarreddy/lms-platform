package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "events")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Event extends BaseEntity {

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "event_type")
    private String eventType;

    @Column(name = "start_time")
    private LocalDateTime startTime;

    @Column(name = "end_time")
    private LocalDateTime endTime;

    @Column(name = "meet_link", columnDefinition = "TEXT")
    private String meetLink;

    private String venue;

    @Column(name = "attendance_required")
    private Boolean attendanceRequired = true;

    @Column(name = "batch_id")
    private Long batchId;

    @Column(name = "plan_id")
    private Long planId;

    /** Optional subject label for DAILY_ATTENDANCE events, used to split the calendar-grid UI by subject. */
    @Column(name = "subject")
    private String subject;
}
