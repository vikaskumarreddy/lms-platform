package com.institute.lms.service.subscription;

import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.OrgSubscriptionAddon;
import com.institute.lms.entity.OrgSubscriptionInstance;
import com.institute.lms.repository.OrgSubscriptionAddonRepository;
import com.institute.lms.repository.OrgSubscriptionInstanceRepository;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.subscription.SubscriptionStatus;
import com.institute.lms.util.JsonUtils;
import com.institute.lms.util.OrganizationContext;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;

/**
 * Resolves what a tenant is entitled to.
 *
 * <p>The resolution order is deliberate and is the whole point of the class:
 * <ol>
 *   <li><strong>Frozen snapshot</strong> from the tenant's subscription instance — the
 *       limits and features as they were when the term was agreed. Never the live
 *       catalog, so editing a plan's price or limits cannot reach an existing
 *       customer. This is what makes grandfathering work.</li>
 *   <li><strong>Negotiated overrides</strong> on the instance, for plans whose limits
 *       are declared configurable (Managed Academy, Enterprise). These replace the
 *       snapshot value for the keys they mention.</li>
 *   <li><strong>Active add-ons</strong>, whose contributions are <em>added</em> to the
 *       result. So a negotiated 1,500-student limit plus 100 purchased seats resolves
 *       to 1,600, which is what a customer who bought both would expect.</li>
 * </ol>
 *
 * <p>Add-ons are read from the purchased row's own frozen {@code incrementsLimitKey} /
 * {@code grantsEntitlementKey}, not from the catalog definition, so re-pointing a
 * catalog add-on later cannot change what an existing customer already paid for.
 *
 * <p>Not cached. Resolution is two indexed lookups and sits on create paths rather than
 * read paths, and a stale entitlement cache is the kind of bug that either blocks a
 * paying customer or hands out a feature they did not buy — neither is worth the
 * microseconds.
 */
@Service
public class EntitlementService {

    private final OrgSubscriptionInstanceRepository instanceRepository;
    private final OrgSubscriptionAddonRepository addonRepository;
    private final OrganizationContext organizationContext;

    public EntitlementService(OrgSubscriptionInstanceRepository instanceRepository,
                              OrgSubscriptionAddonRepository addonRepository,
                              OrganizationContext organizationContext) {
        this.instanceRepository = instanceRepository;
        this.addonRepository = addonRepository;
        this.organizationContext = organizationContext;
    }

    /** Resolves entitlements for the tenant in the current request context. */
    public ResolvedEntitlements resolveCurrent() {
        Long orgId = organizationContext.getCurrentOrgId();
        return orgId == null ? ResolvedEntitlements.none(null) : resolve(orgId);
    }

    /** Resolves entitlements for a named organization. */
    public ResolvedEntitlements resolve(Long organizationId) {
        if (organizationId == null) {
            return ResolvedEntitlements.none(null);
        }
        OrgSubscriptionInstance instance = instanceRepository
                .findByOrganizationIdAndIsCurrentTrue(organizationId)
                .orElse(null);
        if (instance == null) {
            // Fails closed: no subscription means no allowance and no features, rather
            // than an accidental free tier for an organization nobody has sold to yet.
            return ResolvedEntitlements.none(organizationId);
        }
        List<OrgSubscriptionAddon> addons =
                addonRepository.findEffective(organizationId, LocalDateTime.now());
        return resolve(instance, addons);
    }

    /** Resolves from an already-loaded instance and add-on set, avoiding repeat queries. */
    public ResolvedEntitlements resolve(OrgSubscriptionInstance instance,
                                        List<OrgSubscriptionAddon> effectiveAddons) {
        Map<LimitKey, Long> limits = new EnumMap<>(LimitKey.class);
        Map<LimitKey, Long> addonContributions = new EnumMap<>(LimitKey.class);
        Map<Entitlement, Object> entitlements = new EnumMap<>(Entitlement.class);

        Map<String, Object> snapshotLimits = JsonUtils.readMap(instance.getLimitsSnapshot());
        Map<String, Object> overrideLimits = JsonUtils.readMap(instance.getLimitsOverride());

        // Steps 1 and 2: snapshot, with negotiated overrides replacing individual keys.
        for (LimitKey key : LimitKey.values()) {
            Long value;
            if (overrideLimits.containsKey(key.name())) {
                value = JsonUtils.getLong(overrideLimits, key.name(), null);
            } else if (snapshotLimits.containsKey(key.name())) {
                value = JsonUtils.getLong(snapshotLimits, key.name(), null);
            } else {
                // Absent from both means the plan places no ceiling on it.
                value = null;
            }
            // A negative stored value is the explicit "unlimited" sentinel.
            if (value != null && value < 0) {
                value = null;
            }
            limits.put(key, value);
        }

        Map<String, Object> snapshotEntitlements = JsonUtils.readMap(instance.getEntitlementsSnapshot());
        Map<String, Object> overrideEntitlements = JsonUtils.readMap(instance.getEntitlementsOverride());
        applyEntitlementMap(entitlements, snapshotEntitlements);
        applyEntitlementMap(entitlements, overrideEntitlements);

        // Step 3: add-ons raise limits and grant features on top.
        if (effectiveAddons != null) {
            for (OrgSubscriptionAddon addon : effectiveAddons) {
                if (!addon.isEffectiveNow()) {
                    continue;
                }
                LimitKey raised = LimitKey.fromKey(addon.getIncrementsLimitKey());
                if (raised != null) {
                    long quantity = addonQuantity(addon);
                    addonContributions.merge(raised, quantity, Long::sum);
                    Long existing = limits.get(raised);
                    // Adding to an unlimited limit is a no-op — it stays unlimited.
                    if (existing != null) {
                        limits.put(raised, existing + quantity);
                    }
                }
                Entitlement granted = Entitlement.fromKey(addon.getGrantsEntitlementKey());
                if (granted != null) {
                    entitlements.put(granted, Boolean.TRUE);
                }
            }
        }

        SubscriptionStatus status = instance.getEffectiveStatus();

        return new ResolvedEntitlements(
                instance.getOrganizationId(), instance,
                instance.getPlanCode(), instance.getPlanName(),
                status, limits, entitlements, addonContributions);
    }

    /**
     * Builds the frozen limits JSON for a plan, called when a term starts or renews.
     *
     * <p>Null plan limits are omitted rather than written as zero: an absent key means
     * unlimited, and writing 0 would turn an Enterprise agreement's "no ceiling" into
     * "no allowance at all".
     */
    public String snapshotLimits(OrgSubscription plan) {
        Map<String, Object> out = new java.util.LinkedHashMap<>();
        putIfPresent(out, LimitKey.MAX_ACTIVE_STUDENTS, plan.getMaxActiveStudents());
        putIfPresent(out, LimitKey.MAX_FACULTY_ACCOUNTS, plan.getMaxFacultyAccounts());
        putIfPresent(out, LimitKey.MAX_BRANCHES, plan.getMaxBranches());
        putIfPresent(out, LimitKey.MAX_ORGANIZATIONS, plan.getMaxOrganizations());
        putIfPresent(out, LimitKey.STORAGE_GB, plan.getStorageGb());
        if (plan.getIncludedTrainingHours() != null) {
            out.put(LimitKey.INCLUDED_TRAINING_HOURS.name(), plan.getIncludedTrainingHours());
        }
        return JsonUtils.write(out);
    }

    /** Copies the plan's entitlements verbatim as the frozen snapshot. */
    public String snapshotEntitlements(OrgSubscription plan) {
        String raw = plan.getEntitlements();
        return raw == null || raw.isBlank() ? "{}" : raw;
    }

    /**
     * Validates and serialises negotiated limit overrides.
     *
     * <p>Unrecognised keys are dropped rather than stored, so a typo cannot create a
     * limit nothing enforces. A null value is kept as an explicit "unlimited" grant.
     */
    public String buildLimitsOverride(Map<LimitKey, Long> overrides) {
        if (overrides == null || overrides.isEmpty()) {
            return null;
        }
        Map<String, Object> out = new java.util.LinkedHashMap<>();
        overrides.forEach((key, value) -> {
            if (key != null) {
                out.put(key.name(), value != null ? value : LimitKey.UNLIMITED);
            }
        });
        return JsonUtils.write(out);
    }

    private void putIfPresent(Map<String, Object> out, LimitKey key, Integer value) {
        if (value != null) {
            out.put(key.name(), value);
        }
    }

    /** Merges a raw JSON entitlement map, ignoring keys the platform does not recognise. */
    private void applyEntitlementMap(Map<Entitlement, Object> target, Map<String, Object> raw) {
        raw.forEach((key, value) -> {
            Entitlement entitlement = Entitlement.fromKey(key);
            if (entitlement != null) {
                target.put(entitlement, value);
            }
        });
    }

    /**
     * The allowance a single purchased add-on contributes.
     *
     * <p>Quantified add-ons contribute their quantity (100 extra seats); flat ones
     * contribute nothing to a limit — they exist to grant a feature, and treating a
     * flat add-on as "+1 seat" would silently inflate an allowance.
     */
    private long addonQuantity(OrgSubscriptionAddon addon) {
        if (addon.getPricingModel() != null && !addon.getPricingModel().isQuantified()) {
            return 0L;
        }
        return addon.getQty() != null ? addon.getQty() : 0L;
    }
}
