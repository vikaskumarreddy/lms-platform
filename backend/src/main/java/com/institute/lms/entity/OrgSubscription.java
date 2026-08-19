package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * A platform plan in the SaaS catalog — Platform, Platform Plus, Managed Academy,
 * Enterprise, or the assisted Pilot.
 *
 * <p>Do not confuse this with {@link SubscriptionPlan} / {@link Subscription}, which
 * are tenant-scoped and describe plans an academy's <em>students</em> subscribe to
 * inside their own organization. This class is what an <em>organization</em> buys
 * from the platform.
 *
 * <p>Deliberately not a {@link BaseEntity}: it carries no {@code organization_id} and
 * no {@code @TenantId}, so the platform super admin — who runs under a sentinel tenant
 * that matches no real row — can still read the catalog through JPA. Making it
 * tenant-scoped is the mistake V31 made with {@code subscription_plans}, which then
 * needed a backfill migration.
 *
 * <p><strong>This row is a template, not a contract.</strong> Editing a price or a
 * limit here must never change what an existing tenant already agreed to. Enforcement
 * therefore reads the frozen {@code limits_snapshot} / {@code entitlements_snapshot}
 * on the tenant's {@code org_subscription_instances} row, which is copied from this
 * template at purchase or renewal time.
 */
@Entity
@Table(name = "org_subscriptions")
@Data
@NoArgsConstructor
public class OrgSubscription {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Stable machine identifier — PLATFORM, PLATFORM_PLUS, MANAGED_ACADEMY,
     * ENTERPRISE, PILOT. Application logic keys off this, never off {@link #name},
     * so plans can be renamed for marketing without breaking behaviour.
     */
    @Column(nullable = false, unique = true, length = 40)
    private String code;

    @Column(nullable = false)
    private String name;

    /** Short marketing line shown under the plan name on a pricing card. */
    @Column
    private String tagline;

    @Column(columnDefinition = "TEXT")
    private String description;

    // ---- Ordering and visibility ---------------------------------------

    /** Ascending commercial seniority. Used to tell an upgrade from a downgrade. */
    @Column(name = "tier_rank", nullable = false)
    private Integer tierRank = 0;

    @Column(name = "display_order", nullable = false)
    private Integer displayOrder = 0;

    /**
     * Whether this plan appears as a self-serve card on the tenant Account page.
     * The Pilot plan is intentionally false — it is sold, not chosen.
     */
    @Column(name = "is_public", nullable = false)
    private Boolean isPublic = true;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    /** Renders the "recommended / most popular" badge. Set on Platform Plus. */
    @Column(name = "is_popular", nullable = false)
    private Boolean isPopular = false;

    // ---- Pricing -------------------------------------------------------

    @Column(name = "price_monthly")
    private BigDecimal priceMonthly;

    @Column(name = "price_yearly")
    private BigDecimal priceYearly;

    /**
     * The annual saving as a percentage. Stored rather than derived so the
     * commercial intent survives price edits and the plan editor can flag a plan
     * that drifts outside the intended 15-20% band.
     */
    @Column(name = "annual_discount_pct")
    private BigDecimal annualDiscountPct;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    /** Enterprise: no list price, every deal is quoted. */
    @Column(name = "is_custom_priced", nullable = false)
    private Boolean isCustomPriced = false;

    // ---- Tax -----------------------------------------------------------

    /** False means {@link #priceMonthly} excludes GST, which is how prices are stored. */
    @Column(name = "tax_inclusive", nullable = false)
    private Boolean taxInclusive = false;

    /** SAC code. 997331 for the subscription itself; training services use 999293. */
    @Column(name = "hsn_sac_code", length = 10)
    private String hsnSacCode;

    @Column(name = "gst_rate_pct", nullable = false)
    private BigDecimal gstRatePct = new BigDecimal("18.00");

    // ---- Limits (null means unlimited — see LimitKey.UNLIMITED) --------

    @Column(name = "max_active_students")
    private Integer maxActiveStudents;

    @Column(name = "max_faculty_accounts")
    private Integer maxFacultyAccounts;

    @Column(name = "max_branches")
    private Integer maxBranches;

    @Column(name = "max_organizations")
    private Integer maxOrganizations;

    @Column(name = "storage_gb")
    private Integer storageGb;

    /**
     * Trainer hours the base fee already covers. Managed Academy bundles training
     * <em>and</em> the contract meters it hourly; without an explicit included
     * figure those two clauses contradict each other and every engagement becomes
     * an argument about what the fee covered. Purchased hours draw down only after
     * these are consumed.
     */
    @Column(name = "included_training_hours", nullable = false)
    private BigDecimal includedTrainingHours = BigDecimal.ZERO;

    /** Managed and Enterprise agreements may override limits per tenant. */
    @Column(name = "limits_configurable", nullable = false)
    private Boolean limitsConfigurable = false;

    // ---- Overage -------------------------------------------------------

    /**
     * How many extra active students may be bought before an upgrade is required.
     * Set to 25% of {@link #maxActiveStudents} so capacity growth eventually moves
     * the tenant up a tier instead of letting them run indefinitely on add-ons.
     */
    @Column(name = "overage_students_allowed", nullable = false)
    private Integer overageStudentsAllowed = 0;

    /**
     * Per-plan price of an extra active student, which overrides the add-on's own
     * default. Deliberately set ABOVE the next tier's effective per-student rate
     * (40 / 30 / 20 against effective rates of 25 / 26 / 50) so that buying the
     * next plan is always cheaper than stacking seats. At the bottom of the
     * quoted 15-40 band the add-on would have made Platform Plus strictly worse
     * value than staying on Platform.
     */
    @Column(name = "overage_student_price")
    private BigDecimal overageStudentPrice;

    // ---- Entitlements and lifecycle ------------------------------------

    /**
     * JSON object of {@code Entitlement} name to {@code true} or a number. Only
     * granted keys are present; an absent key means not included. Parsed via
     * {@code EntitlementService}, never by hand.
     */
    @Column(columnDefinition = "TEXT", nullable = false)
    private String entitlements = "{}";

    @Column(name = "trial_days", nullable = false)
    private Integer trialDays = 0;

    /** Days after expiry during which the tenant stays read-only before suspension. */
    @Column(name = "grace_days", nullable = false)
    private Integer graceDays = 15;

    /**
     * Defaults to false: with no live payment gateway, an instant self-serve
     * upgrade would grant entitlements against money that has not been collected.
     * The Account page's Upgrade button therefore raises a request for the
     * platform team to approve.
     */
    @Column(name = "self_serve_upgrade_enabled", nullable = false)
    private Boolean selfServeUpgradeEnabled = false;

    @Column(name = "requires_quote", nullable = false)
    private Boolean requiresQuote = false;

    /** Internal delivery notes for the platform team; never shown to tenants. */
    @Column(name = "fulfilment_notes", columnDefinition = "TEXT")
    private String fulfilmentNotes;

    // ---- Legacy columns ------------------------------------------------

    /**
     * Legacy single price, kept in sync with {@link #priceMonthly}.
     * {@code SaasStatsController} still sums this for platform revenue figures.
     */
    @Column(nullable = false)
    private BigDecimal price = BigDecimal.ZERO;

    /**
     * Legacy 'monthly' | 'yearly' | 'custom'. Still read by
     * {@code OrganizationService.computeExpiry} to derive a term length.
     */
    @Column(nullable = false)
    private String period = "monthly";

    /**
     * Legacy JSON array of human-readable feature strings, used for the marketing
     * bullet list on a plan card. The enforceable truth is {@link #entitlements};
     * this is presentation only.
     */
    @Column(columnDefinition = "TEXT")
    private String features = "[]";

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /** True when this plan can never be self-served and must go through sales. */
    @Transient
    public boolean isSalesOnly() {
        return Boolean.TRUE.equals(isCustomPriced) || Boolean.TRUE.equals(requiresQuote);
    }

    /**
     * Effective price for a billing cycle, or null when custom-priced.
     * Falls back to the legacy {@link #price} if the new columns are unset.
     */
    @Transient
    public BigDecimal priceFor(String billingCycle) {
        if (Boolean.TRUE.equals(isCustomPriced)) {
            return null;
        }
        if ("YEARLY".equalsIgnoreCase(billingCycle) || "yearly".equalsIgnoreCase(billingCycle)) {
            return priceYearly;
        }
        return priceMonthly != null ? priceMonthly : price;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        applyDefaults();
        syncLegacyPricing();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
        syncLegacyPricing();
    }

    private void applyDefaults() {
        if (price == null) price = BigDecimal.ZERO;
        if (period == null) period = "monthly";
        if (features == null) features = "[]";
        if (entitlements == null || entitlements.isBlank()) entitlements = "{}";
        if (currency == null) currency = "INR";
        if (isActive == null) isActive = true;
        if (isPopular == null) isPopular = false;
        if (isPublic == null) isPublic = true;
        if (isCustomPriced == null) isCustomPriced = false;
        if (taxInclusive == null) taxInclusive = false;
        if (gstRatePct == null) gstRatePct = new BigDecimal("18.00");
        if (includedTrainingHours == null) includedTrainingHours = BigDecimal.ZERO;
        if (limitsConfigurable == null) limitsConfigurable = false;
        if (overageStudentsAllowed == null) overageStudentsAllowed = 0;
        if (tierRank == null) tierRank = 0;
        if (displayOrder == null) displayOrder = 0;
        if (trialDays == null) trialDays = 0;
        if (graceDays == null) graceDays = 15;
        if (selfServeUpgradeEnabled == null) selfServeUpgradeEnabled = false;
        if (requiresQuote == null) requiresQuote = false;
    }

    /**
     * Keeps the legacy {@code price} column aligned with {@code price_monthly} so
     * existing readers (platform revenue stats, the old plan list) never show a
     * figure that contradicts the pricing card.
     */
    private void syncLegacyPricing() {
        if (priceMonthly != null) {
            price = priceMonthly;
        } else if (Boolean.TRUE.equals(isCustomPriced)) {
            price = BigDecimal.ZERO;
        }
    }
}
