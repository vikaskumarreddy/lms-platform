package com.institute.lms.dto.subscription;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Everything the institute admin's Account page shows: who the organization is, what
 * they are subscribed to, how much of it they are using, and what they are entitled to.
 *
 * <p>Returned as one payload rather than five endpoints so the page renders in a single
 * round trip and cannot show a plan from one moment beside usage from another.
 */
@Data
public class AccountOverviewResponse {

    private OrganizationDetails organization = new OrganizationDetails();
    private SubscriptionDetails subscription;
    private List<UsageMeter> usage = new ArrayList<>();
    private List<EntitlementView> entitlements = new ArrayList<>();
    private List<PurchasedAddonView> addons = new ArrayList<>();
    private PendingChange pendingPlanChange;

    /** Banner to show at the top of the portal, or null when nothing needs attention. */
    private Notice notice;

    /** The organization details captured when the tenant was created. */
    @Data
    public static class OrganizationDetails {
        private Long id;
        private String name;
        private String slug;
        private String domain;
        private String logoUrl;
        private Boolean isActive;
        private String status;

        private String legalName;
        private String gstin;
        private String pan;
        private String billingEmail;
        private String billingPhone;
        private String billingAddress;
        private String city;
        private String stateCode;
        private String placeOfSupply;
        private String pincode;
        private String country;
        private String contactPerson;

        private String poNumber;
        /** Our account owner, so the tenant knows who to contact. */
        private String salesOwner;

        private LocalDateTime createdAt;
        private LocalDateTime purchaseDate;
        private LocalDateTime expiryDate;
        private Integer renewalCount;

        private List<AdminSummary> admins = new ArrayList<>();
    }

    @Data
    public static class AdminSummary {
        private Long id;
        private String name;
        private String email;
        private String phone;
        private Boolean isActive;
    }

    @Data
    public static class SubscriptionDetails {
        private Long instanceId;
        private Long planId;
        private String planCode;
        private String planName;
        private String status;
        private String statusLabel;
        /** FULL, READ_ONLY or NONE — lets the UI disable actions rather than fail them. */
        private String accessLevel;
        private String billingCycle;
        private String billingCycleLabel;

        private BigDecimal unitPrice;
        private String currency;
        private Boolean taxInclusive;
        private BigDecimal gstRatePct;
        /** Price including GST, so the tenant sees what they will actually be charged. */
        private BigDecimal priceWithTax;

        private LocalDateTime periodStart;
        private LocalDateTime periodEnd;
        private LocalDateTime trialEndsAt;
        private LocalDateTime graceEndsAt;
        private Long daysRemaining;
        private Boolean autoRenew;

        private String poNumber;
        private String quotationRef;
        private Boolean limitsCustomised;
    }

    /** One usage bar: how much of an allowance is consumed. */
    @Data
    public static class UsageMeter {
        private String limitKey;
        private String label;
        private long used;
        /** Null means unlimited. */
        private Long limit;
        private boolean unlimited;
        /** How much of the limit came from purchased add-ons rather than the plan. */
        private long fromAddons;
        /** 0-100, capped; null when unlimited. */
        private Integer percentUsed;
        /** OK | WARNING | AT_LIMIT | OVER */
        private String state;
        /**
         * True where exceeding the limit is billed rather than blocked. Only active
         * students behave this way — a learner is never locked out to enforce a cap.
         */
        private boolean meteredNotBlocked;
        private String note;
    }

    @Data
    public static class EntitlementView {
        private String key;
        private String label;
        private String category;
        private String categoryLabel;
        private boolean included;
        private Object value;
        /** True for features that need manual delivery and cannot be self-provisioned. */
        private boolean salesQualified;
    }

    @Data
    public static class PurchasedAddonView {
        private Long id;
        private String addonCode;
        private String addonName;
        private Integer qty;
        private String unitLabel;
        private BigDecimal unitPrice;
        private BigDecimal lineTotal;
        private String status;
        private String billingPeriod;
        private LocalDateTime effectiveFrom;
        private LocalDateTime effectiveTo;
        private boolean awaitingDecision;
    }

    @Data
    public static class PendingChange {
        private Long id;
        private String requestedPlanCode;
        private String requestedPlanName;
        private String requestedBillingCycle;
        private String requestKind;
        private String status;
        private LocalDateTime createdAt;
        private String requestedNote;
    }

    /** A banner: severity plus what the tenant should do about it. */
    @Data
    public static class Notice {
        /** INFO | WARNING | CRITICAL */
        private String severity;
        private String title;
        private String message;
        private String actionLabel;
        /** Machine code so the UI can branch, e.g. SUBSCRIPTION_EXPIRED. */
        private String code;
    }
}
