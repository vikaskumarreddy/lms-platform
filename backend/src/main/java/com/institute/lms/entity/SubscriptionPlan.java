package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Entity
@Table(name = "subscription_plans")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class SubscriptionPlan extends BaseEntity {
    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private BigDecimal price;

    @Column(name = "duration_days")
    private Integer durationDays;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(columnDefinition = "TEXT")
    private String features;

    @Column
    private String color;

    @Column
    private String period;

    @Column(name = "is_popular")
    private Boolean isPopular = false;
}