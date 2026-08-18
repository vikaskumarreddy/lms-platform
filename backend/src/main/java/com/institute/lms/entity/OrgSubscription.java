package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Represents a SaaS plan that can be assigned to an Organization (tenant).
 * Examples: "Platform Only", "Platform + Training Support", "Enterprise".
 */
@Entity
@Table(name = "org_subscriptions")
@Data
@NoArgsConstructor
public class OrgSubscription {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private BigDecimal price = BigDecimal.ZERO;

    /** 'monthly' | 'yearly' | 'custom' */
    @Column(nullable = false)
    private String period = "monthly";

    /** JSON array of feature strings included in this plan. */
    @Column(columnDefinition = "TEXT")
    private String features = "[]";

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "is_popular")
    private Boolean isPopular = false;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (price == null) price = BigDecimal.ZERO;
        if (period == null) period = "monthly";
        if (features == null) features = "[]";
        if (isActive == null) isActive = true;
        if (isPopular == null) isPopular = false;
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}