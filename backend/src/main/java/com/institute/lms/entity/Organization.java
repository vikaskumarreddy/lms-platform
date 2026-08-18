package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Represents a tenant/organization in the SaaS multi-tenant model.
 * Each organization has its own isolated set of data (users, batches, courses, etc.).
 * Admins can create and configure organizations from the Admin portal.
 */
@Entity
@Table(name = "organizations")
@Data
@NoArgsConstructor
public class Organization {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    /** Unique slug used in URLs (e.g., "acme-institute"). */
    @Column(nullable = false, unique = true)
    private String slug;

    /** Optional custom domain (e.g., "institute.acme.com"). */
    @Column(unique = true)
    private String domain;

    /** Path/URL to the uploaded logo file. */
    @Column(name = "logo_url")
    private String logoUrl;

    @Column(name = "is_active")
    private Boolean isActive = true;

    /** Lifecycle status: 'ACTIVE' | 'EXPIRED' (derived from expiry_date when it passes). */
    @Column(nullable = false)
    private String status = "ACTIVE";

    /** Date the current subscription / plan was purchased (or renewed). */
    @Column(name = "purchase_date")
    private LocalDateTime purchaseDate;

    /** Date the current subscription / plan expires. Past this date the org is EXPIRED. */
    @Column(name = "expiry_date")
    private LocalDateTime expiryDate;

    /** Number of times this organization's plan has been renewed. */
    @Column(name = "renewal_count")
    private Integer renewalCount = 0;

    /** Reference to a subscription plan (links to plans table or external plan system). */
    @Column(name = "plan_id")
    private Long planId;

    /** Reference to the org_subscriptions plan assigned to this organization (SaaS tier). */
    @Column(name = "org_subscription_id")
    private Long orgSubscriptionId;

    /** JSON string for flexible tenant-specific settings (brand colors, features, etc.). */
    @Column(columnDefinition = "TEXT")
    private String settings = "{}";

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        if (settings == null) settings = "{}";
        if (isActive == null) isActive = true;
        if (status == null || status.isBlank()) status = "ACTIVE";
        if (renewalCount == null) renewalCount = 0;
        if (purchaseDate == null) purchaseDate = LocalDateTime.now();
        if (expiryDate == null) expiryDate = LocalDateTime.now().plusYears(1);
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
