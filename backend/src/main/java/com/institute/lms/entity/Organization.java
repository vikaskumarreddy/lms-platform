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

    // ---- Billing identity and address (GST) ----------------------------
    //
    // Captured when the organization is created and echoed back on the tenant's
    // Account page. These are not optional extras: a GST-compliant invoice needs
    // the customer's legal name, GSTIN and place of supply, and place of supply
    // decides whether tax splits into CGST+SGST (intra-state) or is charged as
    // IGST (inter-state).

    /** Registered legal entity name, which may differ from the display {@link #name}. */
    @Column(name = "legal_name")
    private String legalName;

    @Column(length = 15)
    private String gstin;

    @Column(length = 10)
    private String pan;

    @Column(name = "billing_email")
    private String billingEmail;

    @Column(name = "billing_phone", length = 30)
    private String billingPhone;

    @Column(name = "billing_address", columnDefinition = "TEXT")
    private String billingAddress;

    @Column(length = 120)
    private String city;

    /** Two-digit GST state code, e.g. "36" for Telangana. Drives the CGST/SGST vs IGST split. */
    @Column(name = "state_code", length = 2)
    private String stateCode;

    @Column(name = "place_of_supply", length = 120)
    private String placeOfSupply;

    @Column(length = 10)
    private String pincode;

    @Column(length = 80)
    private String country = "India";

    @Column(name = "contact_person", length = 160)
    private String contactPerson;

    // ---- Sales context -------------------------------------------------

    /** Customer purchase order number to quote on invoices, where they require one. */
    @Column(name = "po_number", length = 80)
    private String poNumber;

    /** Account owner on our side. Shown to the tenant so they know who to contact. */
    @Column(name = "sales_owner", length = 160)
    private String salesOwner;

    /** Internal notes. Never exposed on the tenant-facing Account page. */
    @Column(columnDefinition = "TEXT")
    private String notes;

    /**
     * Storage consumed by this tenant's uploads, in bytes.
     *
     * <p>A maintained counter rather than a measured figure. Uploads currently land in
     * a local {@code ./uploads} directory with no per-tenant accounting at all, so this
     * is the minimum needed to make a plan's storage allowance enforceable — but it is
     * only as accurate as the write paths that remember to update it. Treat a move to
     * object storage with per-tenant prefixes as the real fix.
     */
    @Column(name = "storage_bytes_used", nullable = false)
    private Long storageBytesUsed = 0L;

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
        if (country == null || country.isBlank()) country = "India";
        if (storageBytesUsed == null) storageBytesUsed = 0L;
    }

    /**
     * True when enough billing identity is present to raise a GST-compliant invoice.
     * Checked before invoicing so a missing GSTIN surfaces as a clear message to the
     * platform team rather than an invoice that cannot be filed.
     */
    @Transient
    public boolean hasBillingIdentity() {
        return legalName != null && !legalName.isBlank()
                && placeOfSupply != null && !placeOfSupply.isBlank()
                && stateCode != null && !stateCode.isBlank();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
