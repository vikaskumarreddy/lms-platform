package com.institute.lms.service.subscription;

import com.institute.lms.entity.OrgSubscriptionInstance;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.subscription.SubscriptionStatus;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * What one tenant is actually entitled to right now, after resolving the frozen plan
 * snapshot, any negotiated overrides, and every active add-on.
 *
 * <p>Immutable and cheap to pass around. Enforcement, the Account page and invoicing
 * all read the same object, so there is exactly one definition of "their limit" in the
 * system rather than three that can drift apart.
 *
 * <p>A limit of {@code null} means unlimited. That is a real state — Enterprise
 * agreements and negotiated custom limits both use it — so callers must check
 * {@link #isUnlimited(LimitKey)} rather than treating null as zero.
 */
public final class ResolvedEntitlements {

    private final Long organizationId;
    private final OrgSubscriptionInstance instance;
    private final String planCode;
    private final String planName;
    private final SubscriptionStatus status;
    private final Map<LimitKey, Long> limits;
    private final Map<Entitlement, Object> entitlements;
    /** Extra allowance contributed by add-ons, kept separate so the UI can explain a total. */
    private final Map<LimitKey, Long> addonContributions;

    ResolvedEntitlements(Long organizationId,
                         OrgSubscriptionInstance instance,
                         String planCode,
                         String planName,
                         SubscriptionStatus status,
                         Map<LimitKey, Long> limits,
                         Map<Entitlement, Object> entitlements,
                         Map<LimitKey, Long> addonContributions) {
        this.organizationId = organizationId;
        this.instance = instance;
        this.planCode = planCode;
        this.planName = planName;
        this.status = status;
        this.limits = Collections.unmodifiableMap(new EnumMap<>(limits));
        this.entitlements = Collections.unmodifiableMap(new EnumMap<>(entitlements));
        this.addonContributions = Collections.unmodifiableMap(new EnumMap<>(addonContributions));
    }

    /**
     * The state of a tenant with no subscription at all. Every limit is zero and no
     * feature is granted, so an unsubscribed organization fails closed rather than
     * inheriting an accidental free-for-all.
     */
    static ResolvedEntitlements none(Long organizationId) {
        Map<LimitKey, Long> zeroed = new EnumMap<>(LimitKey.class);
        for (LimitKey key : LimitKey.values()) {
            zeroed.put(key, 0L);
        }
        return new ResolvedEntitlements(organizationId, null, null, null, null,
                zeroed, new EnumMap<>(Entitlement.class), new EnumMap<>(LimitKey.class));
    }

    public Long getOrganizationId() {
        return organizationId;
    }

    /** The current subscription term, or null when the organization has none. */
    public OrgSubscriptionInstance getInstance() {
        return instance;
    }

    public String getPlanCode() {
        return planCode;
    }

    /** Display name of the plan, falling back to a readable phrase when unsubscribed. */
    public String getPlanName() {
        return planName != null ? planName : "no active plan";
    }

    /** The clock-corrected status, so an unswept expiry is still treated as expired. */
    public SubscriptionStatus getStatus() {
        return status;
    }

    public boolean hasSubscription() {
        return instance != null;
    }

    public boolean allowsWrites() {
        return status != null && status.allowsWrites();
    }

    public boolean allowsReads() {
        return status != null && status.allowsReads();
    }

    public Map<LimitKey, Long> getLimits() {
        return limits;
    }

    public Map<Entitlement, Object> getEntitlements() {
        return entitlements;
    }

    public Map<LimitKey, Long> getAddonContributions() {
        return addonContributions;
    }

    /** The effective ceiling for a limit, or null when unlimited. */
    public Long limit(LimitKey key) {
        return limits.get(key);
    }

    public boolean isUnlimited(LimitKey key) {
        return LimitKey.isUnlimited(limits.get(key));
    }

    /** How much of a limit came from purchased add-ons rather than the plan itself. */
    public long addonContribution(LimitKey key) {
        Long value = addonContributions.get(key);
        return value != null ? value : 0L;
    }

    /**
     * Whether a feature is granted. A numeric entitlement counts as granted when its
     * value is non-zero, so {@code WEBSITE_PAGES_INCLUDED: 8} reads as enabled.
     */
    public boolean has(Entitlement entitlement) {
        Object value = entitlements.get(entitlement);
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean b) {
            return b;
        }
        if (value instanceof Number n) {
            return n.doubleValue() != 0d;
        }
        return Boolean.parseBoolean(value.toString());
    }

    /** The numeric value of a quantified entitlement, or {@code fallback} when absent. */
    public BigDecimal number(Entitlement entitlement, BigDecimal fallback) {
        Object value = entitlements.get(entitlement);
        if (value == null) {
            return fallback;
        }
        if (value instanceof BigDecimal bd) {
            return bd;
        }
        if (value instanceof Number n) {
            return BigDecimal.valueOf(n.doubleValue());
        }
        try {
            return new BigDecimal(value.toString().trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    public long numberAsLong(Entitlement entitlement, long fallback) {
        return number(entitlement, BigDecimal.valueOf(fallback)).longValue();
    }

    /** Limits keyed by name, for JSON responses. */
    public Map<String, Object> limitsAsMap() {
        Map<String, Object> out = new LinkedHashMap<>();
        limits.forEach((key, value) -> out.put(key.name(), value));
        return out;
    }

    /** Entitlements keyed by name, for JSON responses. */
    public Map<String, Object> entitlementsAsMap() {
        Map<String, Object> out = new LinkedHashMap<>();
        entitlements.forEach((key, value) -> out.put(key.name(), value));
        return out;
    }
}
