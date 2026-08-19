package com.institute.lms.controller;

import com.institute.lms.dto.subscription.AccountOverviewResponse;
import com.institute.lms.dto.subscription.AddonResponse;
import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.UnauthorizedException;
import com.institute.lms.repository.OrgBillingEventRepository;
import com.institute.lms.repository.OrgSubscriptionAddonRepository;
import com.institute.lms.repository.OrgSubscriptionInstanceRepository;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.service.PlanAddonService;
import com.institute.lms.service.subscription.AccountService;
import com.institute.lms.service.subscription.EntitlementService;
import com.institute.lms.service.subscription.SubscriptionLifecycleService;
import com.institute.lms.subscription.BillingCycle;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * The institute admin's Account surface: organization details, current subscription,
 * usage, entitlements, plan cards, add-ons and billing history.
 *
 * <p>Everything is scoped to the caller's own organization — a tenant admin cannot read
 * or act on another organization here, whatever they put in the request. The platform
 * super admin may pass {@code ?organizationId=} to inspect a specific tenant, which is
 * how support sees what the customer sees.
 *
 * <p>This whole path is whitelisted in {@code SubscriptionStateInterceptor}, so it stays
 * reachable when a subscription has expired or been suspended. A tenant locked out of
 * the page explaining why they are locked out, and carrying the button to fix it, would
 * be self-defeating.
 */
@RestController
@RequestMapping("/api/account")
public class AccountController {

    private final AccountService accountService;
    private final SubscriptionLifecycleService lifecycleService;
    private final EntitlementService entitlementService;
    private final PlanAddonService addonService;
    private final OrgSubscriptionService planService;
    private final OrgSubscriptionAddonRepository purchasedAddonRepository;
    private final OrgSubscriptionInstanceRepository instanceRepository;
    private final OrgBillingEventRepository billingEventRepository;
    private final com.institute.lms.repository.OrgPlanChangeRequestRepository changeRequestRepository;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    public AccountController(AccountService accountService,
                             SubscriptionLifecycleService lifecycleService,
                             EntitlementService entitlementService,
                             PlanAddonService addonService,
                             OrgSubscriptionService planService,
                             OrgSubscriptionAddonRepository purchasedAddonRepository,
                             OrgSubscriptionInstanceRepository instanceRepository,
                             OrgBillingEventRepository billingEventRepository,
                             com.institute.lms.repository.OrgPlanChangeRequestRepository changeRequestRepository,
                             OrganizationContext organizationContext,
                             UserContext userContext) {
        this.changeRequestRepository = changeRequestRepository;
        this.accountService = accountService;
        this.lifecycleService = lifecycleService;
        this.entitlementService = entitlementService;
        this.addonService = addonService;
        this.planService = planService;
        this.purchasedAddonRepository = purchasedAddonRepository;
        this.instanceRepository = instanceRepository;
        this.billingEventRepository = billingEventRepository;
        this.organizationContext = organizationContext;
        this.userContext = userContext;
    }

    /** Everything the Account page needs, in one call. */
    @GetMapping("/overview")
    public AccountOverviewResponse overview(@RequestParam(required = false) Long organizationId) {
        return accountService.buildOverview(resolveOrganization(organizationId));
    }

    /**
     * The plan cards.
     *
     * <p>Each carries {@code isCurrent} and an {@code action} of CURRENT, UPGRADE,
     * DOWNGRADE or CONTACT_SALES — which is what lets the applied plan render a disabled
     * "Current Plan" button while the others offer a real action.
     */
    @GetMapping("/plans")
    public List<Map<String, Object>> plans(@RequestParam(required = false) Long organizationId) {
        return accountService.buildPlanCards(resolveOrganization(organizationId));
    }

    /** Add-ons available on the tenant's current plan, plus what they already hold. */
    @GetMapping("/addons")
    public Map<String, Object> addons(@RequestParam(required = false) Long organizationId) {
        Long orgId = resolveOrganization(organizationId);
        var resolved = entitlementService.resolve(orgId);

        List<AddonResponse> available = new ArrayList<>();
        for (PlanAddon addon : addonService.getAvailableForPlan(resolved.getPlanCode())) {
            // Internal delivery notes are withheld: several describe work that has to be
            // scoped before it can be promised to a customer.
            available.add(AddonResponse.from(addon, false));
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("available", available);
        out.put("purchased", purchasedAddonRepository.findByOrganizationIdOrderByCreatedAtDesc(orgId));
        return out;
    }

    /**
     * Requests a plan change.
     *
     * <p>Deliberately a request, not an immediate switch. With no payment gateway
     * collecting money at the moment of the click, applying an upgrade straight away
     * would hand over a more expensive plan's entitlements on trust. Plans marked
     * self-serve are applied automatically by the lifecycle service.
     */
    @PostMapping("/plan-change-request")
    public ResponseEntity<Map<String, Object>> requestPlanChange(@RequestBody Map<String, Object> body,
                                                                 @RequestParam(required = false) Long organizationId) {
        Long orgId = resolveOrganization(organizationId);
        User current = userContext.currentUser();

        Long planId = asLong(body.get("planId"));
        String planCode = body.get("planCode") != null ? body.get("planCode").toString() : null;
        if (planId == null && planCode != null) {
            planId = planService.requireByCode(planCode).getId();
        }
        if (planId == null) {
            throw BadRequestException.field("planId", "is required");
        }

        BillingCycle cycle = BillingCycle.fromName(
                body.get("billingCycle") != null ? body.get("billingCycle").toString() : null);
        String note = body.get("note") != null ? body.get("note").toString() : null;

        OrgPlanChangeRequest request = lifecycleService.requestPlanChange(
                orgId, planId, cycle,
                current != null ? current.getId() : null,
                current != null ? current.getEmail() : null,
                note);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", request.getId());
        response.put("status", request.getStatus());
        response.put("requestedPlanCode", request.getRequestedPlanCode());
        response.put("message", OrgPlanChangeRequest.STATUS_APPROVED.equals(request.getStatus())
                ? "Your plan has been updated."
                : "Thanks — we've received your request and will be in touch to arrange billing.");
        return ResponseEntity.ok(response);
    }

    /**
     * Withdraws the tenant's own pending plan change request.
     *
     * <p>Ownership is verified <em>before</em> anything is modified. Checking afterwards
     * would let a tenant cancel another organization's request and only then be told
     * they were not allowed to.
     */
    @DeleteMapping("/plan-change-request/{id}")
    public ResponseEntity<Map<String, Object>> cancelPlanChange(@PathVariable Long id,
                                                                @RequestParam(required = false) Long organizationId) {
        Long orgId = resolveOrganization(organizationId);
        OrgPlanChangeRequest request = changeRequestRepository.findById(id)
                .orElseThrow(() -> com.institute.lms.exception.ResourceNotFoundException
                        .of("Plan change request", id));

        if (!orgId.equals(request.getOrganizationId())) {
            throw UnauthorizedException.forbidden("That request belongs to a different organization.");
        }
        if (!request.isPending()) {
            throw new BadRequestException(
                    "This request has already been " + request.getStatus().toLowerCase() + ".");
        }

        User current = userContext.currentUser();
        request.setStatus(OrgPlanChangeRequest.STATUS_CANCELLED);
        request.setDecidedBy(current != null ? current.getEmail() : "tenant");
        request.setDecidedAt(LocalDateTime.now());
        request.setDecisionNote("Withdrawn by the organization.");
        changeRequestRepository.save(request);

        return ResponseEntity.ok(Map.of("message", "Request withdrawn."));
    }

    /**
     * Requests an add-on.
     *
     * <p>Recorded as PENDING_APPROVAL (or PENDING_QUOTE for quoted items) and grants
     * nothing until the platform team approves — same reasoning as plan changes.
     */
    @PostMapping("/addon-request")
    public ResponseEntity<Map<String, Object>> requestAddon(@RequestBody Map<String, Object> body,
                                                            @RequestParam(required = false) Long organizationId) {
        Long orgId = resolveOrganization(organizationId);
        User current = userContext.currentUser();

        String addonCode = body.get("addonCode") != null ? body.get("addonCode").toString() : null;
        if (addonCode == null) {
            throw BadRequestException.field("addonCode", "is required");
        }
        PlanAddon addon = addonService.requireByCode(addonCode);
        if (!Boolean.TRUE.equals(addon.getIsActive())) {
            throw new BadRequestException(ErrorCode.ADDON_NOT_FOUND,
                    "'" + addon.getName() + "' is not currently available.");
        }

        var resolved = entitlementService.resolve(orgId);
        if (!com.institute.lms.util.JsonUtils.listContains(addon.getAppliesToPlanCodes(), resolved.getPlanCode())) {
            throw new BadRequestException(ErrorCode.ADDON_NOT_APPLICABLE, String.format(
                    "'%s' is not available on the %s plan.", addon.getName(), resolved.getPlanName()));
        }

        Integer requestedQty = body.get("qty") != null ? asInt(body.get("qty")) : addon.getMinQty();
        int qty = addonService.validateQuantity(addon, requestedQty);

        OrgSubscriptionAddon purchase = new OrgSubscriptionAddon();
        purchase.setOrganizationId(orgId);
        purchase.setSubscriptionInstanceId(resolved.getInstance() != null
                ? resolved.getInstance().getId() : null);
        purchase.setAddonId(addon.getId());
        purchase.setAddonCode(addon.getCode());
        purchase.setAddonName(addon.getName());
        purchase.setQty(qty);
        purchase.setUnitPrice(addon.getDefaultUnitPrice());
        purchase.setUnitLabel(addon.getUnitLabel());
        purchase.setPricingModel(addon.getPricingModel());
        // Frozen so a later catalog edit cannot change what this purchase grants.
        purchase.setIncrementsLimitKey(addon.getIncrementsLimitKey());
        purchase.setGrantsEntitlementKey(addon.getGrantsEntitlementKey());
        purchase.setBillingPeriod(addon.isRecurring() ? "MONTHLY" : "ONE_TIME");
        purchase.setStatus(Boolean.TRUE.equals(addon.getRequiresQuote())
                ? OrgSubscriptionAddon.STATUS_PENDING_QUOTE
                : OrgSubscriptionAddon.STATUS_PENDING_APPROVAL);
        purchase.setEffectiveFrom(LocalDateTime.now());
        purchase.setHsnSacCode(addon.getHsnSacCode());
        purchase.setGstRatePct(addon.getGstRatePct());
        purchase.setRequestedBy(current != null ? current.getEmail() : null);
        purchase.setNotes(body.get("note") != null ? body.get("note").toString() : null);

        OrgSubscriptionAddon saved = purchasedAddonRepository.save(purchase);

        lifecycleService.recordEvent(orgId,
                resolved.getInstance() != null ? resolved.getInstance().getId() : null,
                com.institute.lms.subscription.BillingEventType.ADDON_REQUESTED, null, null,
                current != null ? current.getEmail() : null,
                String.format("Requested %s x%d.", addon.getName(), qty), null);

        return ResponseEntity.ok(Map.of(
                "id", saved.getId(),
                "status", saved.getStatus(),
                "message", Boolean.TRUE.equals(addon.getRequiresQuote())
                        ? "Thanks — we'll prepare a quotation and get back to you."
                        : "Thanks — we've received your request and will confirm shortly."));
    }

    /** Subscription terms, newest first — the tenant's own billing history. */
    @GetMapping("/subscription-history")
    public List<OrgSubscriptionInstance> subscriptionHistory(@RequestParam(required = false) Long organizationId) {
        return instanceRepository.findByOrganizationIdOrderByCreatedAtDesc(resolveOrganization(organizationId));
    }

    /** The billing activity timeline. */
    @GetMapping("/billing-events")
    public List<OrgBillingEvent> billingEvents(@RequestParam(required = false) Long organizationId,
                                               @RequestParam(defaultValue = "50") int limit) {
        return billingEventRepository.findByOrganizationIdOrderByCreatedAtDesc(
                resolveOrganization(organizationId), PageRequest.of(0, Math.min(limit, 200)));
    }

    /**
     * Resolves which organization this request concerns.
     *
     * <p>A tenant admin always gets their own, regardless of what they pass — the
     * {@code organizationId} parameter is honoured only for the platform super admin, so
     * it cannot be used to read another academy's account.
     */
    private Long resolveOrganization(Long requested) {
        userContext.requireOrgAdmin();

        if (userContext.isAdmin()) {
            if (requested != null) {
                return requested;
            }
            Long contextOrg = organizationContext.getCurrentOrgId();
            if (contextOrg != null) {
                return contextOrg;
            }
            throw BadRequestException.field("organizationId",
                    "is required when the platform admin is not browsing a specific tenant");
        }

        User current = userContext.currentUser();
        Long ownOrg = current != null ? current.getOrganizationId() : organizationContext.getCurrentOrgId();
        if (ownOrg == null) {
            throw new BadRequestException("Your account is not linked to an organization.");
        }
        return ownOrg;
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

    private Integer asInt(Object value) {
        Long parsed = asLong(value);
        return parsed != null ? parsed.intValue() : null;
    }
}
