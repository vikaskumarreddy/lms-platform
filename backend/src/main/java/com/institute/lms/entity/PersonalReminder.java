package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import java.time.Instant;

@Entity
@Table(name = "personal_reminders")
@Data
@EqualsAndHashCode(callSuper = true)
public class PersonalReminder extends BaseEntity {
    @Column(nullable = false)
    private Long userId;
    @Column(nullable = false, length = 200)
    private String title;
    @Column(nullable = false, length = 2000)
    private String description = "";
    @Column(nullable = false)
    private Instant dueAt;
    @Column(nullable = false, length = 80)
    private String timeZone;
    @Column(nullable = false, length = 20)
    private String status = "PENDING";
    @Column(nullable = false, length = 20)
    private String notificationStatus = "PENDING";
    private Instant notifiedAt;
    @Column(nullable = false)
    private int attempts;
    private Instant lastAttemptAt;
}
