package com.institute.lms.service.subscription;

import com.institute.lms.dto.subscription.AccountOverviewResponse;
import com.institute.lms.dto.subscription.PlanResponse;
import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.subscription.SubscriptionStatus;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Assembles the tenant-facing Account page.
 *
 * <p>Everything here is read-only and scoped to one organization. The page has to answer
 * three questions at a glance — what did we buy, how much of it are we using, and what
 * happens next — so the overview is returned as a single payload rather than several
 * endpoints that could disagree with each other mid-render.
 */
@Service
public class AccountService {

    private static final long BYTES_PER_GB = 1024L * 1024L * 1024L;
    /** Usage above this fraction of the allowance shows as a warning. */
    private static final double WARNING_THRESHOLD = 0.8;

    private final OrganizationRepository organizationRepository;
    private final UserRepository userRepository;
    private final OrgSubscriptionAddonRepository addonRepository;
    private final OrgPlanChangeRequestRepository changeRequestRepository;
    private final OrgSubscriptionService planService;
    private final EntitlementService entitlementService;
    private final UsageService usageService;

    public AccountService(OrganizationRepository organizationRepository,
                          UserRepository userRepository,
                          OrgSubscriptionAddonRepository addonRepository,
                          OrgPlanChangeRequestRepository changeRequestRepository,
                          OrgSubscriptionService planService,
                          EntitlementService entitlementService,
                          UsageService usageService) {
        this.organizationRepository = organizationRepository;
        this.userRepository = userRepository;
        this.addonRepository = addonRepository;
        this.changeRequestRepository = changeRequestRepository;
        this.planService = planService;
        this.entitlementService = entitlementService;
        this.usageService = usageService;
    }

    public AccountOverviewResponse buildOverview(Long organizationId) {
        Organization org = organizationRepository.findById(organizationId)
                .orElseThrow(() -> com.institute.lms.exception.ResourceNotFoundException
                        .of("Organization", organizationId));

        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);

        AccountOverviewResponse response = new AccountOverviewResponse();
        response.setOrganization(toOrganizationDetails(org));
        response.setSubscription(toSubscriptionDetails(resolved));
        response.setUsage(buildUsageMeters(organizationId, resolved));
        response.setEntitlements(buildEntitlementViews(resolved));
        response.setAddons(buildAddonViews(organizationId));
        response.setNotice(buildNotice(resolved));

        changeRequestRepository
                .findByOrganizationIdAndStatus(organizationId, OrgPlanChangeRequest.STATUS_PENDING)
                .ifPresent(request -> response.setPendingPlanChange(toPendingChange(request)));

        return response;
    }

    /**
     * The plan cards, each flagged with how it relates to the tenant's current plan.
     *
     * <p>{@code isCurrent} is what makes the applied plan's button render disabled and
     * read "Current Plan", while every other card offers an action.
     */
    public List<Map<String, Object>> buildPlanCards(Long organizationId) {
        ResolvedEntitlements resolved = entitlementService.resolve(organizationId);
        String currentCode = resolved.getPlanCode();

        int currentRank = planService.getByCode(currentCode)
                .map(p -> p.getTierRank() != null ? p.getTierRank() : 0)
                .orElse(-1);

        List<Map<String, Object>> cards = new ArrayList<>();
        for (OrgSubscription plan : planService.getPublicPlans()) {
            PlanResponse view = PlanResponse.from(plan);
            // Delivery notes are internal guidance; never shown to a tenant.
            view.setFulfilmentNotes(null);

            boolean isCurrent = plan.getCode().equals(currentCode);
            int rank = plan.getTierRank() != null ? plan.getTierRank() : 0;

            String action;
            if (isCurrent) {
                action = "CURRENT";
            } else if (Boolean.TRUE.equals(plan.getIsCustomPriced()) || Boolean.TRUE.equals(plan.getRequiresQuote())) {
                // Enterprise and Managed are quoted, so the honest call to action is to
                // talk to us rather than a button implying instant provisioning.
                action = "CONTACT_SALES";
            } else if (currentRank < 0 || rank > currentRank) {
                action = "UPGRADE";
            } else {
                action = "DOWNGRADE";
            }

            Map<String, Object> card = new java.util.LinkedHashMap<>();
            card.put("plan", view);
            card.put("isCurrent", isCurrent);
            card.put("action", action);
            card.put("actionLabel", switch (action) {
                case "CURRENT" -> "Current Plan";
                case "CONTACT_SALES" -> "Contact Sales";
                case "DOWNGRADE" -> "Downgrade";
                default -> "Upgrade";
            });
            card.put("recommended", Boolean.TRUE.equals(plan.getIsPopular()));

            // Tell the tenant up front when a downgrade cannot work, so the button can be
            // disabled with a reason instead of failing after they click it.
            if ("DOWNGRADE".equals(action)) {
                String blocker = downgradeBlocker(organizationId, plan);
                card.put("blocked", blocker != null);
                card.put("blockedReason", blocker);
            } else {
                card.put("blocked", false);
            }
            cards.add(card);
        }
        return cards;
    }

    /** Returns why a downgrade to this plan would fail, or null when it would succeed. */
    private String downgradeBlocker(Long organizationId, OrgSubscription target) {
        record Check(LimitKey key, Integer limit) { }
        List<Check> checks = List.of(
                new Check(LimitKey.MAX_ACTIVE_STUDENTS, target.getMaxActiveStudents()),
                new Check(LimitKey.MAX_FACULTY_ACCOUNTS, target.getMaxFacultyAccounts()),
                new Check(LimitKey.MAX_BRANCHES, target.getMaxBranches()),
                new Check(LimitKey.STORAGE_GB, target.getStorageGb()));

        for (Check check : checks) {
            if (check.limit() == null) {
                continue;
            }
            long used = usageService.usageOf(check.key(), organizationId);
            if (used > check.limit()) {
                return String.format("You currently have %d %s; this plan allows %d.",
                        used, check.key().getPluralLabel(), check.limit());
            }
        }
        return null;
    }

    private AccountOverviewResponse.OrganizationDetails toOrganizationDetails(Organization org) {
        AccountOverviewResponse.OrganizationDetails d = new AccountOverviewResponse.OrganizationDetails();
        d.setId(org.getId());
        d.setName(org.getName());
        d.setSlug(org.getSlug());
        d.setDomain(org.getDomain());
        d.setLogoUrl(org.getLogoUrl());
        d.setIsActive(org.getIsActive());
        d.setStatus(org.getStatus());

        d.setLegalName(org.getLegalName());
        d.setGstin(org.getGstin());
        d.setPan(org.getPan());
        d.setBillingEmail(org.getBillingEmail());
        d.setBillingPhone(org.getBillingPhone());
        d.setBillingAddress(org.getBillingAddress());
        d.setCity(org.getCity());
        d.setStateCode(org.getStateCode());
        d.setPlaceOfSupply(org.getPlaceOfSupply());
        d.setPincode(org.getPincode());
        d.setCountry(org.getCountry());
        d.setContactPerson(org.getContactPerson());

        d.setPoNumber(org.getPoNumber());
        d.setSalesOwner(org.getSalesOwner());
        // org.getNotes() is deliberately NOT copied — those are internal remarks.

        d.setCreatedAt(org.getCreatedAt());
        d.setPurchaseDate(org.getPurchaseDate());
        d.setExpiryDate(org.getExpiryDate());
        d.setRenewalCount(org.getRenewalCount());

        // Native lookup: User is tenant-scoped, so a derived query would return nothing
        // when this is called by the platform super admin.
        List<AccountOverviewResponse.AdminSummary> admins = new ArrayList<>();
        for (User u : userRepository.findNonGhostAdminsByOrganizationId(
                org.getId(), User.UserRole.INSTITUTE_ADMIN.name())) {
            if (Boolean.TRUE.equals(u.getIsGhost())) {
                continue;
            }
            AccountOverviewResponse.AdminSummary a = new AccountOverviewResponse.AdminSummary();
            a.setId(u.getId());
            a.setName(u.getName());
            a.setEmail(u.getEmail());
            a.setPhone(u.getPhone());
            a.setIsActive(u.getIsActive());
            admins.add(a);
        }
        d.setAdmins(admins);
        return d;
    }

    private AccountOverviewResponse.SubscriptionDetails toSubscriptionDetails(ResolvedEntitlements resolved) {
        OrgSubscriptionInstance instance = resolved.getInstance();
        if (instance == null) {
            return null;
        }
        AccountOverviewResponse.SubscriptionDetails s = new AccountOverviewResponse.SubscriptionDetails();
        s.setInstanceId(instance.getId());
        s.setPlanId(instance.getPlanId());
        s.setPlanCode(instance.getPlanCode());
        s.setPlanName(instance.getPlanName());

        SubscriptionStatus status = resolved.getStatus();
        s.setStatus(status != null ? status.name() : null);
        s.setStatusLabel(status != null ? status.getLabel() : null);
        s.setAccessLevel(status != null ? status.getAccessLevel().name() : null);

        s.setBillingCycle(instance.getBillingCycle().name());
        s.setBillingCycleLabel(instance.getBillingCycle().getLabel());

        s.setUnitPrice(instance.getUnitPrice());
        s.setCurrency(instance.getCurrency());
        s.setTaxInclusive(instance.getTaxInclusive());
        s.setGstRatePct(instance.getGstRatePct());
        // Prices are stored exclusive of GST, so show the tax-inclusive figure too —
        // 18% is a large enough difference that leaving it implicit invites disputes.
        if (instance.getUnitPrice() != null && !Boolean.TRUE.equals(instance.getTaxInclusive())) {
            BigDecimal rate = instance.getGstRatePct() != null
                    ? instance.getGstRatePct() : BigDecimal.valueOf(18);
            s.setPriceWithTax(instance.getUnitPrice()
                    .multiply(BigDecimal.ONE.add(rate.divide(BigDecimal.valueOf(100), 6, RoundingMode.HALF_UP)))
                    .setScale(2, RoundingMode.HALF_UP));
        } else {
            s.setPriceWithTax(instance.getUnitPrice());
        }

        s.setPeriodStart(instance.getPeriodStart());
        s.setPeriodEnd(instance.getPeriodEnd());
        s.setTrialEndsAt(instance.getTrialEndsAt());
        s.setGraceEndsAt(instance.getGraceEndsAt());
        s.setDaysRemaining(instance.getDaysRemaining());
        s.setAutoRenew(instance.getAutoRenew());

        s.setPoNumber(instance.getPoNumber());
        s.setQuotationRef(instance.getQuotationRef());
        s.setLimitsCustomised(instance.getLimitsOverride() != null
                && !instance.getLimitsOverride().isBlank());
        return s;
    }

    private List<AccountOverviewResponse.UsageMeter> buildUsageMeters(Long organizationId,
                                                                     ResolvedEntitlements resolved) {
        List<AccountOverviewResponse.UsageMeter> meters = new ArrayList<>();
        for (LimitKey key : LimitKey.values()) {
            // Not meaningful inside a single tenant's account view.
            if (key == LimitKey.MAX_ORGANIZATIONS) {
                continue;
            }
            AccountOverviewResponse.UsageMeter m = new AccountOverviewResponse.UsageMeter();
            m.setLimitKey(key.name());
            m.setLabel(capitalise(key.getPluralLabel()));

            long used = usageService.usageOf(key, organizationId);
            Long limit = resolved.limit(key);
            m.setUsed(used);
            m.setLimit(limit);
            m.setUnlimited(limit == null);
            m.setFromAddons(resolved.addonContribution(key));

            if (limit == null || limit <= 0) {
                m.setPercentUsed(limit == null ? null : 100);
                m.setState(limit == null ? "OK" : (used > 0 ? "OVER" : "OK"));
            } else {
                int pct = (int) Math.min(100, Math.round(used * 100.0 / limit));
                m.setPercentUsed(pct);
                if (used > limit) {
                    m.setState("OVER");
                } else if (used == limit) {
                    m.setState("AT_LIMIT");
                } else if (used >= limit * WARNING_THRESHOLD) {
                    m.setState("WARNING");
                } else {
                    m.setState("OK");
                }
            }

            if (key == LimitKey.MAX_ACTIVE_STUDENTS) {
                // The one limit that bills rather than blocks. Say so plainly, so an
                // academy over the line understands they are not about to lose access.
                m.setMeteredNotBlocked(true);
                long records = usageService.studentRecords(organizationId);
                m.setNote(String.format(
                        "%d students on record; %d were active this month. Inactive and alumni accounts "
                                + "stay on the platform without using your allowance.", records, used));
                if ("OVER".equals(m.getState())) {
                    m.setNote(m.getNote() + " Activity above your allowance is billed as overage — "
                            + "no student is ever locked out.");
                }
            } else if (key == LimitKey.STORAGE_GB) {
                long bytes = usageService.storageBytes(organizationId);
                m.setNote(String.format("%.2f GB used", bytes / (double) BYTES_PER_GB));
            } else if (key == LimitKey.INCLUDED_TRAINING_HOURS && (limit == null || limit == 0)) {
                continue; // no training hours in this plan; hiding the meter avoids noise
            }
            meters.add(m);
        }
        return meters;
    }

    private List<AccountOverviewResponse.EntitlementView> buildEntitlementViews(ResolvedEntitlements resolved) {
        List<AccountOverviewResponse.EntitlementView> views = new ArrayList<>();
        for (Entitlement e : Entitlement.values()) {
            boolean included = resolved.has(e);
            Object value = resolved.getEntitlements().get(e);
            // Numeric entitlements are only interesting when granted; boolean ones are
            // listed either way so the tenant can see what an upgrade would add.
            if (!included && e.getValueType() == Entitlement.ValueType.NUMBER) {
                continue;
            }
            AccountOverviewResponse.EntitlementView v = new AccountOverviewResponse.EntitlementView();
            v.setKey(e.name());
            v.setLabel(e.getLabel());
            v.setCategory(e.getCategory().name());
            v.setCategoryLabel(e.getCategory().getLabel());
            v.setIncluded(included);
            v.setValue(value);
            v.setSalesQualified(e.isSalesQualified());
            views.add(v);
        }
        return views;
    }

    private List<AccountOverviewResponse.PurchasedAddonView> buildAddonViews(Long organizationId) {
        List<AccountOverviewResponse.PurchasedAddonView> views = new ArrayList<>();
        for (OrgSubscriptionAddon a : addonRepository.findByOrganizationIdOrderByCreatedAtDesc(organizationId)) {
            AccountOverviewResponse.PurchasedAddonView v = new AccountOverviewResponse.PurchasedAddonView();
            v.setId(a.getId());
            v.setAddonCode(a.getAddonCode());
            v.setAddonName(a.getAddonName());
            v.setQty(a.getQty());
            v.setUnitLabel(a.getUnitLabel());
            v.setUnitPrice(a.getUnitPrice());
            v.setLineTotal(a.getLineTotal());
            v.setStatus(a.getStatus());
            v.setBillingPeriod(a.getBillingPeriod());
            v.setEffectiveFrom(a.getEffectiveFrom());
            v.setEffectiveTo(a.getEffectiveTo());
            v.setAwaitingDecision(a.isAwaitingDecision());
            views.add(v);
        }
        return views;
    }

    /**
     * The banner. Returns null when nothing needs saying — a portal that always shows a
     * notice trains people to ignore notices.
     */
    private AccountOverviewResponse.Notice buildNotice(ResolvedEntitlements resolved) {
        if (!resolved.hasSubscription()) {
            return notice("CRITICAL", "No subscription assigned",
                    "This organization does not have a plan yet, so most features are unavailable. "
                            + "Contact your account manager to activate one.",
                    "Contact us", "SUBSCRIPTION_MISSING");
        }

        SubscriptionStatus status = resolved.getStatus();
        OrgSubscriptionInstance instance = resolved.getInstance();

        switch (status) {
            case SUSPENDED:
                return notice("CRITICAL", "Account suspended",
                        "Access has been suspended. Contact your account manager to restore it.",
                        "Contact us", "SUBSCRIPTION_SUSPENDED");
            case CANCELLED:
                return notice("CRITICAL", "Subscription cancelled",
                        "Your subscription was cancelled. Your data is retained — reactivate to resume.",
                        "Reactivate", "SUBSCRIPTION_CANCELLED");
            case EXPIRED:
            case READ_ONLY:
                return notice("CRITICAL", "Subscription expired — read-only",
                        "Your " + resolved.getPlanName() + " subscription has expired, so the portal is "
                                + "read-only. Nothing has been deleted; renew to resume making changes.",
                        "Renew now", "SUBSCRIPTION_EXPIRED");
            case GRACE:
                return notice("WARNING", "Your plan has ended",
                        "Your term ended on " + formatDate(instance.getPeriodEnd())
                                + ". You still have full access until " + formatDate(instance.getGraceEndsAt())
                                + ", after which the portal becomes read-only.",
                        "Renew now", "SUBSCRIPTION_GRACE");
            case PAST_DUE:
                return notice("WARNING", "Payment overdue",
                        "An invoice is overdue. Your academy is unaffected for now, but please settle it "
                                + "to avoid interruption.",
                        "View invoices", "PAYMENT_OVERDUE");
            case TRIALING:
                return notice("INFO", "Trial in progress",
                        "Your trial runs until " + formatDate(instance.getTrialEndsAt()) + ".",
                        "See plans", "TRIAL_ACTIVE");
            case PILOT:
                return notice("INFO", "Assisted pilot in progress",
                        "Your pilot runs until " + formatDate(instance.getPeriodEnd())
                                + ". On conversion to an annual plan, your pilot fee is credited in full "
                                + "and all your data carries over.",
                        "Convert to annual", "PILOT_ACTIVE");
            default:
                break;
        }

        // Renewal reminder in the final fortnight of a term.
        Long days = instance.getDaysRemaining();
        if (Boolean.FALSE.equals(instance.getAutoRenew()) && days != null && days >= 0 && days <= 14) {
            return notice("WARNING", "Renewal needed",
                    "Your plan ends in " + days + " day" + (days == 1 ? "" : "s")
                            + " and auto-renew is off.",
                    "Renew now", "RENEWAL_DUE");
        }

        // Overage: informational, never alarming — nothing is at risk of being cut off.
        if (!resolved.isUnlimited(LimitKey.MAX_ACTIVE_STUDENTS)) {
            long limit = resolved.limit(LimitKey.MAX_ACTIVE_STUDENTS);
            long active = usageService.activeStudents(resolved.getOrganizationId());
            if (active > limit) {
                return notice("WARNING", "Over your active-student allowance",
                        String.format("%d students were active this month against an allowance of %d. "
                                        + "The extra %d are billed as overage — no student is blocked. "
                                        + "Upgrading is usually cheaper than paying overage.",
                                active, limit, active - limit),
                        "Compare plans", "OVERAGE_ACTIVE");
            }
        }
        return null;
    }

    private AccountOverviewResponse.PendingChange toPendingChange(OrgPlanChangeRequest request) {
        AccountOverviewResponse.PendingChange c = new AccountOverviewResponse.PendingChange();
        c.setId(request.getId());
        c.setRequestedPlanCode(request.getRequestedPlanCode());
        c.setRequestedPlanName(planService.getByCode(request.getRequestedPlanCode())
                .map(OrgSubscription::getName).orElse(request.getRequestedPlanCode()));
        c.setRequestedBillingCycle(request.getRequestedBillingCycle().name());
        c.setRequestKind(request.getRequestKind());
        c.setStatus(request.getStatus());
        c.setCreatedAt(request.getCreatedAt());
        c.setRequestedNote(request.getRequestedNote());
        return c;
    }

    private AccountOverviewResponse.Notice notice(String severity, String title, String message,
                                                 String actionLabel, String code) {
        AccountOverviewResponse.Notice n = new AccountOverviewResponse.Notice();
        n.setSeverity(severity);
        n.setTitle(title);
        n.setMessage(message);
        n.setActionLabel(actionLabel);
        n.setCode(code);
        return n;
    }

    private String formatDate(LocalDateTime dateTime) {
        return dateTime != null ? dateTime.toLocalDate().toString() : "an unspecified date";
    }

    private String capitalise(String s) {
        if (s == null || s.isEmpty()) {
            return s;
        }
        return Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }
}
