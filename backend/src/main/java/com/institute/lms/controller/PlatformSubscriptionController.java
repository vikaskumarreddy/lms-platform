package com.institute.lms.controller;

import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.repository.*;
import com.institute.lms.service.PlanAddonService;
import com.institute.lms.service.subscription.EntitlementService;
import com.institute.lms.service.subscription.ResolvedEntitlements;
import com.institute.lms.service.subscription.SubscriptionLifecycleService;
import com.institute.lms.service.subscription.UsageService;
import com.institute.lms.subscription.BillingCycle;
import com.institute.lms.subscription.BillingEventType;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Platform super-admin control over tenant subscriptions: assigning a plan, changing it,
 * renewing, cancelling, suspending, overriding limits, and approving the requests
 * tenants raise from their Account page.
 *
 * <p>Every endpoint here is super-admin only. Tenants act through {@code /api/account},
 * which raises requests rather than applying changes — the approval step lives here
 * because, with no live payment gateway, granting a higher plan is a commercial decision
 * someone has to take.
 */
@RestController
@RequestMapping("/api/platform/subscriptions")
public class PlatformSubscriptionController {

    private final SubscriptionLifecycleService lifecycleService;
    private final EntitlementService entitlementService;
    private final UsageService usageService;
    private final PlanAddonService addonService;
    private final OrgSubscriptionInstanceRepository instanceRepository;
    private final OrgSubscriptionAddonRepository purchasedAddonRepository;
    private final OrgPlanChangeRequestRepository changeRequestRepository;
    private final OrganizationRepository organizationRepository;
    private final UserContext userContext;

    public PlatformSubscriptionController(SubscriptionLifecycleService lifecycleService,
                                          EntitlementService entitlementService,
                                          UsageService usageService,
                                          PlanAddonService addonService,
                                          OrgSubscriptionInstanceRepository instanceRepository,
                                          OrgSubscriptionAddonRepository purchasedAddonRepository,
                                          OrgPlanChangeRequestRepository changeRequestRepository,
                                          OrganizationRepository organizationRepository,
                                          UserContext userContext) {
        this.lifecycleService = lifecycleService;
        this.entitlementService = entitlementService;
        this.usageService = usageService;
        this.addonService = addonService;
        this.instanceRepository = instanceRepository;
        this.purchasedAddonRepository = purchasedAddonRepository;
        this.changeRequestRepository = changeRequestRepository;
        this.organizationRepository = organizationRepository;
        this.userContext = userContext;
    }

    /** The current subscription, usage and limits for one tenant. */
    @GetMapping("/{organizationId}")
    public Map<String, Object> getSubscription(@PathVariable Long organizationId) {
        userContext.requireSuperAdmin();
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("organizationId", organizationId);
        out.put("instance", resolved.getInstance());
        out.put("planCode", resolved.getPlanCode());
        out.put("planName", resolved.getPlanName());
        out.put("status", resolved.getStatus() != null ? resolved.getStatus().name() : null);
        out.put("limits", resolved.limitsAsMap());
        out.put("entitlements", resolved.entitlementsAsMap());
        out.put("usage", usageAsMap(organizationId));
        out.put("addons", purchasedAddonRepository.findByOrganizationIdOrderByCreatedAtDesc(organizationId));
        out.put("history", instanceRepository.findByOrganizationIdOrderByCreatedAtDesc(organizationId));
        return out;
    }

    /** Starts or replaces a tenant's subscription. */
    @PostMapping("/{organizationId}/subscribe")
    public ResponseEntity<OrgSubscriptionInstance> subscribe(@PathVariable Long organizationId,
                                                             @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long planId = asLong(body.get("planId"));
        if (planId == null) {
            throw BadRequestException.field("planId", "is required");
        }
        return ResponseEntity.ok(
                lifecycleService.subscribe(organizationId, planId, readOptions(body)));
    }

    /** Moves a tenant to another plan, prorating the change. */
    @PostMapping("/{organizationId}/change-plan")
    public ResponseEntity<OrgSubscriptionInstance> changePlan(@PathVariable Long organizationId,
                                                              @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long planId = asLong(body.get("planId"));
        if (planId == null) {
            throw BadRequestException.field("planId", "is required");
        }
        BillingCycle cycle = body.get("billingCycle") != null
                ? BillingCycle.fromName(body.get("billingCycle").toString()) : null;
        return ResponseEntity.ok(lifecycleService.changePlan(organizationId, planId, cycle,
                actor(), str(body.get("note"))));
    }

    @PostMapping("/{organizationId}/renew")
    public ResponseEntity<OrgSubscriptionInstance> renew(@PathVariable Long organizationId) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(lifecycleService.renew(organizationId, actor()));
    }

    /**
     * Cancels a subscription. Defaults to taking effect at term end, since the tenant
     * has already paid for the remainder.
     */
    @PostMapping("/{organizationId}/cancel")
    public ResponseEntity<OrgSubscriptionInstance> cancel(@PathVariable Long organizationId,
                                                          @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Map<String, Object> payload = body != null ? body : Map.of();
        boolean atPeriodEnd = payload.get("immediate") == null
                || !Boolean.parseBoolean(payload.get("immediate").toString());
        return ResponseEntity.ok(lifecycleService.cancel(organizationId, atPeriodEnd,
                str(payload.get("reason")), actor()));
    }

    @PostMapping("/{organizationId}/reactivate")
    public ResponseEntity<OrgSubscriptionInstance> reactivate(@PathVariable Long organizationId,
                                                              @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long planId = body != null ? asLong(body.get("planId")) : null;
        return ResponseEntity.ok(lifecycleService.reactivate(organizationId, planId, actor()));
    }

    @PostMapping("/{organizationId}/suspend")
    public ResponseEntity<OrgSubscriptionInstance> suspend(@PathVariable Long organizationId,
                                                           @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(lifecycleService.suspend(organizationId,
                body != null ? str(body.get("reason")) : null, actor()));
    }

    @PostMapping("/{organizationId}/resume")
    public ResponseEntity<OrgSubscriptionInstance> resume(@PathVariable Long organizationId) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(lifecycleService.resume(organizationId, actor()));
    }

    /**
     * Applies negotiated limits, for the plans that allow it (Managed Academy,
     * Enterprise). A null value means unlimited.
     */
    @PostMapping("/{organizationId}/limits")
    public ResponseEntity<OrgSubscriptionInstance> overrideLimits(@PathVariable Long organizationId,
                                                                  @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Map<LimitKey, Long> overrides = new LinkedHashMap<>();
        body.forEach((key, value) -> {
            LimitKey limitKey = LimitKey.fromKey(key);
            if (limitKey == null) {
                throw new BadRequestException("'" + key + "' is not a limit the platform enforces.");
            }
            overrides.put(limitKey, value != null ? asLong(value) : null);
        });
        return ResponseEntity.ok(lifecycleService.overrideLimits(organizationId, overrides, actor()));
    }

    // =====================================================================
    // Add-ons
    // =====================================================================

    /** Grants an add-on directly, bypassing the request flow. */
    @PostMapping("/{organizationId}/addons")
    public ResponseEntity<OrgSubscriptionAddon> addAddon(@PathVariable Long organizationId,
                                                         @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        String code = str(body.get("addonCode"));
        if (code == null) {
            throw BadRequestException.field("addonCode", "is required");
        }
        PlanAddon addon = addonService.requireByCode(code);
        int qty = addonService.validateQuantity(addon,
                body.get("qty") != null ? asLong(body.get("qty")).intValue() : null);

        // Clamped into the agreed band so a negotiated price cannot silently fall
        // outside what the catalog permits.
        BigDecimal unitPrice = addon.resolveUnitPrice(
                body.get("unitPrice") != null ? new BigDecimal(body.get("unitPrice").toString()) : null);

        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);

        OrgSubscriptionAddon purchase = new OrgSubscriptionAddon();
        purchase.setOrganizationId(organizationId);
        purchase.setSubscriptionInstanceId(resolved.getInstance() != null
                ? resolved.getInstance().getId() : null);
        purchase.setAddonId(addon.getId());
        purchase.setAddonCode(addon.getCode());
        purchase.setAddonName(addon.getName());
        purchase.setQty(qty);
        purchase.setUnitPrice(unitPrice);
        purchase.setUnitLabel(addon.getUnitLabel());
        purchase.setPricingModel(addon.getPricingModel());
        // Frozen so later catalog edits cannot change what this purchase grants.
        purchase.setIncrementsLimitKey(addon.getIncrementsLimitKey());
        purchase.setGrantsEntitlementKey(addon.getGrantsEntitlementKey());
        purchase.setBillingPeriod(addon.isRecurring() ? "MONTHLY" : "ONE_TIME");
        purchase.setStatus(OrgSubscriptionAddon.STATUS_ACTIVE);
        purchase.setEffectiveFrom(LocalDateTime.now());
        purchase.setHsnSacCode(addon.getHsnSacCode());
        purchase.setGstRatePct(addon.getGstRatePct());
        purchase.setApprovedBy(actor());
        purchase.setApprovedAt(LocalDateTime.now());
        purchase.setNotes(str(body.get("note")));

        OrgSubscriptionAddon saved = purchasedAddonRepository.save(purchase);
        lifecycleService.recordEvent(organizationId, purchase.getSubscriptionInstanceId(),
                BillingEventType.ADDON_ADDED, null, null, actor(),
                String.format("Added %s x%d at %s.", addon.getName(), qty,
                        unitPrice != null ? unitPrice.toPlainString() : "no charge"), null);
        return ResponseEntity.ok(saved);
    }

    /** Approves a tenant's pending add-on request, making it effective. */
    @PostMapping("/addons/{addonId}/approve")
    public ResponseEntity<OrgSubscriptionAddon> approveAddon(@PathVariable Long addonId,
                                                             @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireSuperAdmin();
        OrgSubscriptionAddon purchase = purchasedAddonRepository.findById(addonId)
                .orElseThrow(() -> com.institute.lms.exception.ResourceNotFoundException
                        .of("Add-on purchase", addonId));
        if (!purchase.isAwaitingDecision()) {
            throw new BadRequestException("This add-on is already " + purchase.getStatus().toLowerCase() + ".");
        }
        if (body != null && body.get("unitPrice") != null) {
            purchase.setUnitPrice(new BigDecimal(body.get("unitPrice").toString()));
        }
        if (purchase.getUnitPrice() == null) {
            throw new BadRequestException(
                    "Set an agreed price before approving — a quoted add-on cannot be invoiced without one.");
        }
        purchase.setStatus(OrgSubscriptionAddon.STATUS_ACTIVE);
        purchase.setApprovedBy(actor());
        purchase.setApprovedAt(LocalDateTime.now());
        purchase.setEffectiveFrom(LocalDateTime.now());

        OrgSubscriptionAddon saved = purchasedAddonRepository.save(purchase);
        lifecycleService.recordEvent(purchase.getOrganizationId(), purchase.getSubscriptionInstanceId(),
                BillingEventType.ADDON_ADDED, null, null, actor(),
                String.format("Approved %s x%d.", purchase.getAddonName(), purchase.getQty()), null);
        return ResponseEntity.ok(saved);
    }

    /** Ends an add-on. The row is retained so billing history stays intact. */
    @DeleteMapping("/addons/{addonId}")
    public ResponseEntity<Map<String, Object>> removeAddon(@PathVariable Long addonId) {
        userContext.requireSuperAdmin();
        OrgSubscriptionAddon purchase = purchasedAddonRepository.findById(addonId)
                .orElseThrow(() -> com.institute.lms.exception.ResourceNotFoundException
                        .of("Add-on purchase", addonId));
        purchase.setStatus(OrgSubscriptionAddon.STATUS_CANCELLED);
        purchase.setEffectiveTo(LocalDateTime.now());
        purchasedAddonRepository.save(purchase);

        lifecycleService.recordEvent(purchase.getOrganizationId(), purchase.getSubscriptionInstanceId(),
                BillingEventType.ADDON_REMOVED, null, null, actor(),
                "Removed " + purchase.getAddonName() + ".", null);
        return ResponseEntity.ok(Map.of("message", "Add-on removed."));
    }

    // =====================================================================
    // Plan change request queue
    // =====================================================================

    /** Pending tenant requests awaiting a decision, oldest first. */
    @GetMapping("/change-requests")
    public List<Map<String, Object>> pendingChangeRequests() {
        userContext.requireSuperAdmin();
        List<Map<String, Object>> out = new ArrayList<>();
        for (OrgPlanChangeRequest request : changeRequestRepository
                .findByStatusOrderByCreatedAtAsc(OrgPlanChangeRequest.STATUS_PENDING)) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("request", request);
            organizationRepository.findById(request.getOrganizationId()).ifPresent(org -> {
                m.put("organizationName", org.getName());
                m.put("organizationSlug", org.getSlug());
            });
            m.put("currentUsage", usageAsMap(request.getOrganizationId()));
            out.add(m);
        }
        return out;
    }

    @PostMapping("/change-requests/{id}/approve")
    public ResponseEntity<OrgPlanChangeRequest> approveChangeRequest(@PathVariable Long id,
                                                                     @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(lifecycleService.approvePlanChange(id, actor(),
                body != null ? str(body.get("note")) : null));
    }

    @PostMapping("/change-requests/{id}/reject")
    public ResponseEntity<OrgPlanChangeRequest> rejectChangeRequest(@PathVariable Long id,
                                                                    @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(lifecycleService.rejectPlanChange(id, actor(),
                body != null ? str(body.get("note")) : null));
    }

    /** Add-on requests awaiting a decision, across all tenants. */
    @GetMapping("/addon-requests")
    public List<OrgSubscriptionAddon> pendingAddonRequests() {
        userContext.requireSuperAdmin();
        return purchasedAddonRepository.findAwaitingDecision();
    }

    // =====================================================================
    // Helpers
    // =====================================================================

    private Map<String, Object> usageAsMap(Long organizationId) {
        Map<String, Object> usage = new LinkedHashMap<>();
        usageService.usageSnapshot(organizationId)
                .forEach((key, value) -> usage.put(key.name(), value));
        usage.put("STUDENT_RECORDS", usageService.studentRecords(organizationId));
        return usage;
    }

    private SubscriptionLifecycleService.SubscribeOptions readOptions(Map<String, Object> body) {
        SubscriptionLifecycleService.SubscribeOptions options =
                new SubscriptionLifecycleService.SubscribeOptions();
        options.actor = actor();
        if (body.get("billingCycle") != null) {
            options.billingCycle = BillingCycle.fromName(body.get("billingCycle").toString());
        }
        if (body.get("agreedPrice") != null) {
            options.agreedPrice = new BigDecimal(body.get("agreedPrice").toString());
        }
        if (body.get("periodEnd") != null) {
            options.periodEnd = LocalDateTime.parse(body.get("periodEnd").toString());
        }
        if (body.get("startTrial") != null) {
            options.startTrial = Boolean.parseBoolean(body.get("startTrial").toString());
        }
        if (body.get("autoRenew") != null) {
            options.autoRenew = Boolean.parseBoolean(body.get("autoRenew").toString());
        }
        if (body.get("discountAmount") != null) {
            options.discountAmount = new BigDecimal(body.get("discountAmount").toString());
        }
        options.poNumber = str(body.get("poNumber"));
        options.quotationRef = str(body.get("quotationRef"));
        options.salesOwner = str(body.get("salesOwner"));
        options.couponCode = str(body.get("couponCode"));
        options.notes = str(body.get("notes"));
        options.changeNote = str(body.get("changeNote"));

        // Negotiated limits supplied at subscribe time, for configurable plans.
        Object limits = body.get("limitOverrides");
        if (limits instanceof Map<?, ?> raw && !raw.isEmpty()) {
            Map<LimitKey, Long> overrides = new LinkedHashMap<>();
            raw.forEach((key, value) -> {
                LimitKey limitKey = LimitKey.fromKey(String.valueOf(key));
                if (limitKey != null) {
                    overrides.put(limitKey, value != null ? asLong(value) : null);
                }
            });
            options.limitOverrides = overrides;
        }
        return options;
    }

    private String actor() {
        User user = userContext.currentUser();
        return user != null ? user.getEmail() : "platform-admin";
    }

    private String str(Object value) {
        return value != null ? value.toString() : null;
    }

    private Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
