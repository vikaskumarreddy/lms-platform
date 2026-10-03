package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * A schedulable interview slot for an INTERNAL placement drive. Admin
 * creates a set of open slots; a student books one via "Schedule my slot",
 * closing the loop between the placement drive and actual interview tracking.
 */
@Entity
@Table(name = "interview_slots")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class InterviewSlot extends BaseEntity {

    @Column(name = "drive_id", nullable = false)
    private Long driveId;

    @Column(name = "slot_time", nullable = false)
    private LocalDateTime slotTime;

    @Column
    private String location;

    @Column
    private String notes;

    @Column(name = "booked_by_user_id")
    private Long bookedByUserId;

    @Column(name = "booked_at")
    private LocalDateTime bookedAt;

    @Column(name = "faculty_id")
    private Long facultyId;

    @Column(name = "faculty_name")
    private String facultyName;

    @Column(name = "faculty_email")
    private String facultyEmail;

    @Column(name = "room_code")
    private String roomCode;

    /** AVAILABLE, BOOKED, COMPLETED, CANCELLED */
    @Column(nullable = false)
    private String status = "AVAILABLE";
}
