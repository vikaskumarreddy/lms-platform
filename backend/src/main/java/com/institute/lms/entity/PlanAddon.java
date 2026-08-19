package com.institute.lms.entity;

import com.institute.lms.subscription.AddonCategory;
import com.institute.lms.subscription.AddonPricingModel;
import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * A purchasable add-on definition in the platform catalog — extra seats, storage,
 * communication credits, services, or training.
 *
 * <p>This is the product template. What a tenant has actually bought is recorded on
 * {@code org_subscription_addons}, which freezes the agreed unit price.
 *
 * <p>Two fields carry the enforcement semantics, so that
 * {@code EntitlementService} can resolve effective limits as
 * <em>plan snapshot + active add-ons + per-tenant overrides</em> without any
 * add-on-specific branching:
 * <ul>
 *   <li>{@link #incrementsLimitKey} raises a {@code LimitKey} allowance</li>
 *   <li>{@link #grantsEntitlementKey} switches on an {@code Entitlement}</li>
 * </ul>
 *
 * <p>Like {@link OrgSubscription}, this is intentionally not a {@link BaseEntity} —
 * no {@code organization_id}, no {@code @TenantId} — so the platform super admin can
 * read the catalog through JPA.
 */
@Entity
@Table(name = "plan_addons")
@Data
@NoArgsConstructor
public class PlanAddon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 60)
    private String code;

    @Column(nullable = false, length = 160)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private AddonCategory category;

    @Enumerated(EnumType.STRING)
    @Column(name = "pricing_model", nullable = false, length = 20)
    private AddonPricingModel pricingModel;

    /** Human unit noun shown next to a quantity, e.g. "active student", "GB", "SMS". */
    @Column(name = "unit_label", length = 60)
    private String unitLabel;

    // ---- Price band ----------------------------------------------------
    // The commercial rates were specified as ranges, so the band is stored and
    // enforced when a price is entered. This keeps negotiated discounting inside
    // agreed limits without needing a code change per deal.

    @Column(name = "unit_price_min")
    private BigDecimal unitPriceMin;

    @Column(name = "unit_price_max")
    private BigDecimal unitPriceMax;

    @Column(name = "default_unit_price")
    private BigDecimal defaultUnitPrice;

    // ---- Quantity rules ------------------------------------------------

    @Column(name = "min_qty", nullable = false)
    private Integer minQty = 1;

    @Column(name = "max_qty")
    private Integer maxQty;

    /** Sold in blocks — credits in thousands, storage in tens of GB. */
    @Column(name = "qty_increment", nullable = false)
    private Integer qtyIncrement = 1;

    // ---- Enforcement hooks ---------------------------------------------

    /** Name of a {@code LimitKey} whose allowance this add-on raises, or null. */
    @Column(name = "increments_limit_key", length = 60)
    private String incrementsLimitKey;

    /** Name of an {@code Entitlement} this add-on switches on, or null. */
    @Column(name = "grants_entitlement_key", length = 60)
    private String grantsEntitlementKey;

    /**
     * JSON array of plan codes this add-on may be attached to; null means any plan.
     * Used to stop, for example, a branch being sold to a single-branch Platform
     * tenant who has no feature to use it with.
     */
    @Column(name = "applies_to_plan_codes", columnDefinition = "TEXT")
    private String appliesToPlanCodes;

    // ---- Fulfilment ----------------------------------------------------

    /** True when the add-on cannot be self-served and needs a quotation first. */
    @Column(name = "requires_quote", nullable = false)
    private Boolean requiresQuote = false;

    /**
     * How this is actually delivered, including anything the platform cannot do
     * today. Internal only — never shown to a tenant, because several entries
     * describe work that has to be scoped before it can be promised.
     */
    @Column(name = "fulfilment_notes", columnDefinition = "TEXT")
    private String fulfilmentNotes;

    @Column(name = "hsn_sac_code", length = 10)
    private String hsnSacCode;

    @Column(name = "gst_rate_pct", nullable = false)
    private BigDecimal gstRatePct = new BigDecimal("18.00");

    @Column(name = "tax_inclusive", nullable = false)
    private Boolean taxInclusive = false;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;

    @Column(name = "display_order", nullable = false)
    private Integer displayOrder = 0;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /** True for recurring add-ons that appear on every invoice. */
    @Transient
    public boolean isRecurring() {
        return pricingModel == AddonPricingModel.PER_UNIT_MONTH
                || pricingModel == AddonPricingModel.FLAT_MONTH;
    }

    /** True when quantity is meaningful; flat and quoted add-ons ignore it. */
    @Transient
    public boolean isQuantified() {
        return pricingModel == AddonPricingModel.PER_UNIT_MONTH
                || pricingModel == AddonPricingModel.PER_UNIT_ONCE;
    }

    /**
     * Clamps a proposed unit price into the agreed band, falling back to the
     * default when none is supplied. Returning a clamped value rather than
     * throwing keeps bulk imports and sales-entered figures from failing hard on
     * a rounding difference; the caller decides whether to surface the adjustment.
     */
    @Transient
    public BigDecimal resolveUnitPrice(BigDecimal proposed) {
        BigDecimal price = proposed != null ? proposed : defaultUnitPrice;
        if (price == null) {
            return null;
        }
        if (unitPriceMin != null && price.compareTo(unitPriceMin) < 0) {
            return unitPriceMin;
        }
        if (unitPriceMax != null && price.compareTo(unitPriceMax) > 0) {
            return unitPriceMax;
        }
        return price;
    }

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
        if (updatedAt == null) updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
        applyDefaults();
    }

    private void applyDefaults() {
        if (minQty == null) minQty = 1;
        if (qtyIncrement == null || qtyIncrement < 1) qtyIncrement = 1;
        if (requiresQuote == null) requiresQuote = false;
        if (gstRatePct == null) gstRatePct = new BigDecimal("18.00");
        if (taxInclusive == null) taxInclusive = false;
        if (isActive == null) isActive = true;
        if (displayOrder == null) displayOrder = 0;
        if (category == null) category = AddonCategory.SERVICES;
        if (pricingModel == null) pricingModel = AddonPricingModel.QUOTED;
    }
}
