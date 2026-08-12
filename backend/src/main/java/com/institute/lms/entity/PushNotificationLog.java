package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Records which (user, reminderKey) push reminders have already been sent so
 * scheduled jobs (deadline/class reminders) never notify the same event twice.
 */
@Entity
@Table(name = "push_notification_log")
@Data
@NoArgsConstructor
public class PushNotificationLog {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "reminder_key", nullable = false)
    private String reminderKey;

    @Column(name = "sent_at")
    private LocalDateTime sentAt = LocalDateTime.now();
}
