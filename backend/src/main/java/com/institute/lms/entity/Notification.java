package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Notification extends BaseEntity {

    @Column(name = "user_id")
    private Long userId;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String message;

    @Column
    private String type;

    @Column(name = "is_read")
    private Boolean isRead = false;

    @Column(name = "action_url", columnDefinition = "TEXT")
    private String actionUrl;

    @Column(name = "target_type")
    private String targetType = "ALL";

    @Column(name = "target_id")
    private Long targetId;

    @Column
    private Boolean broadcast = false;
}