package com.institute.lms.service;

import com.institute.lms.dto.subscription.PlanRequest;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.OrgSubscriptionRepository;
import com.institute.lms.repository.OrganizationRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Manages the platform plan catalog.
 *
 * <p>Note what this service deliberately does <em>not</em> do: changing a plan here
 * never changes what an existing tenant is entitled to. Enforcement reads the frozen
 * snapshot on the tenant's subscription instance, so editing Platform's student limit
 * does not silently re-limit or reprice the academies already on it. That separation
 * is what makes plan grandfathering possible at all.
 */
@Service
public class OrgSubscriptionService {

    private final OrgSubscriptionRepository orgSubscriptionRepository;
    private final OrganizationRepository organizationRepository;

    public OrgSubscriptionService(OrgSubscriptionRepository orgSubscriptionRepository,
                                  OrganizationRepository organizationRepository) {
        this.orgSubscriptionRepository = orgSubscriptionRepository;
        this.organizationRepository = organizationRepository;
    }

    /** Full catalog for the platform editor, including retired and non-public plans. */
    public List<OrgSubscription> getAll() {
        return orgSubscriptionRepository.findAllByOrderByDisplayOrderAscTierRankAsc();
    }

    /** Plans shown as self-serve cards on a tenant's Account page. */
    public List<OrgSubscription> getPublicPlans() {
        return orgSubscriptionRepository.findByIsPublicTrueAndIsActiveTrueOrderByDisplayOrderAsc();
    }

    public OrgSubscription getById(Long id) {
        return orgSubscriptionRepository.findById(id).orElse(null);
    }

    public OrgSubscription requireById(Long id) {
        return orgSubscriptionRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(ErrorCode.PLAN_NOT_FOUND,
                        "Subscription plan " + id + " was not found"));
    }

    public Optional<OrgSubscription> getByCode(String code) {
        return code == null ? Optional.empty() : orgSubscriptionRepository.findByCode(code);
    }

    public OrgSubscription requireByCode(String code) {
        return getByCode(code).orElseThrow(() -> new ResourceNotFoundException(ErrorCode.PLAN_NOT_FOUND,
                "Subscription plan '" + code + "' was not found"));
    }

    /** How many organizations are assigned this plan. Used by the delete guard. */
    public long countOrganizationsUsing(Long planId) {
        return organizationRepository.countByOrgSubscriptionId(planId);
    }

    /**
     * The cheapest active plan senior to {@code plan} that raises the given student
     * allowance, used to name a concrete upgrade target in a quota error. Returns
     * empty when the tenant is already on the top tier.
     */
    public Optional<OrgSubscription> findUpgradeCandidate(OrgSubscription plan) {
        if (plan == null) {
            return Optional.empty();
        }
        int rank = plan.getTierRank() != null ? plan.getTierRank() : 0;
        return orgSubscriptionRepository
                .findByIsActiveTrueAndTierRankGreaterThanOrderByTierRankAsc(rank)
                .stream()
                .filter(p -> Boolean.TRUE.equals(p.getIsPublic()))
                .findFirst();
    }

    @Transactional
    public OrgSubscription create(PlanRequest request) {
        if (request.getName() == null || request.getName().isBlank()) {
            throw BadRequestException.field("name", "is required");
        }
        OrgSubscription plan = new OrgSubscription();
        plan.setCode(resolveNewCode(request));
        apply(request, plan);
        validate(plan);
        return orgSubscriptionRepository.save(plan);
    }

    @Transactional
    public OrgSubscription update(Long id, PlanRequest request) {
        OrgSubscription plan = requireById(id);
        // The code is the stable identifier application logic keys off, and existing
        // subscription instances reference it. Renaming is fine; recoding is not.
        if (request.getCode() != null && !request.getCode().equalsIgnoreCase(plan.getCode())) {
            throw new BadRequestException("A plan's code cannot be changed once created; "
                    + "create a new plan instead. Existing subscriptions reference '" + plan.getCode() + "'.");
        }
        apply(request, plan);
        validate(plan);
        return orgSubscriptionRepository.save(plan);
    }

    /**
     * Retires a plan. Deletion is refused while organizations still reference it,
     * because their frozen snapshots resolve the plan name and code for display.
     */
    @Transactional
    public void delete(Long id) {
        OrgSubscription plan = requireById(id);
        long inUse = countOrganizationsUsing(id);
        if (inUse > 0) {
            throw new BadRequestException(ErrorCode.PLAN_IN_USE,
                    "Cannot delete '" + plan.getName() + "': it is assigned to " + inUse
                            + (inUse == 1 ? " organization" : " organizations")
                            + ". Deactivate it instead so it stops being offered to new customers.");
        }
        orgSubscriptionRepository.deleteById(id);
    }

    /** Copies non-null request fields onto the entity. Null means "leave unchanged". */
    private void apply(PlanRequest r, OrgSubscription p) {
        if (r.getName() != null) p.setName(r.getName().trim());
        if (r.getTagline() != null) p.setTagline(r.getTagline());
        if (r.getDescription() != null) p.setDescription(r.getDescription());

        if (r.getTierRank() != null) p.setTierRank(r.getTierRank());
        if (r.getDisplayOrder() != null) p.setDisplayOrder(r.getDisplayOrder());
        if (r.getIsPublic() != null) p.setIsPublic(r.getIsPublic());
        if (r.getIsActive() != null) p.setIsActive(r.getIsActive());
        if (r.getIsPopular() != null) p.setIsPopular(r.getIsPopular());

        if (r.getPriceMonthly() != null) p.setPriceMonthly(r.getPriceMonthly());
        if (r.getPriceYearly() != null) p.setPriceYearly(r.getPriceYearly());
        if (r.getCurrency() != null) p.setCurrency(r.getCurrency());
        if (r.getIsCustomPriced() != null) p.setIsCustomPriced(r.getIsCustomPriced());

        // Legacy single price still posted by the current editor: treat it as the
        // monthly price when the explicit field was not supplied, so old and new
        // clients converge on the same value.
        if (r.getPriceMonthly() == null && r.getPrice() != null) {
            p.setPriceMonthly(r.getPrice());
        }
        if (r.getPeriod() != null) p.setPeriod(r.getPeriod());

        if (r.getTaxInclusive() != null) p.setTaxInclusive(r.getTaxInclusive());
        if (r.getHsnSacCode() != null) p.setHsnSacCode(r.getHsnSacCode());
        if (r.getGstRatePct() != null) p.setGstRatePct(r.getGstRatePct());

        if (r.getMaxActiveStudents() != null) p.setMaxActiveStudents(r.getMaxActiveStudents());
        if (r.getMaxFacultyAccounts() != null) p.setMaxFacultyAccounts(r.getMaxFacultyAccounts());
        if (r.getMaxBranches() != null) p.setMaxBranches(r.getMaxBranches());
        if (r.getMaxOrganizations() != null) p.setMaxOrganizations(r.getMaxOrganizations());
        if (r.getStorageGb() != null) p.setStorageGb(r.getStorageGb());
        if (r.getIncludedTrainingHours() != null) p.setIncludedTrainingHours(r.getIncludedTrainingHours());
        if (r.getLimitsConfigurable() != null) p.setLimitsConfigurable(r.getLimitsConfigurable());

        if (r.getOverageStudentsAllowed() != null) p.setOverageStudentsAllowed(r.getOverageStudentsAllowed());
        if (r.getOverageStudentPrice() != null) p.setOverageStudentPrice(r.getOverageStudentPrice());

        if (r.getTrialDays() != null) p.setTrialDays(r.getTrialDays());
        if (r.getGraceDays() != null) p.setGraceDays(r.getGraceDays());
        if (r.getSelfServeUpgradeEnabled() != null) p.setSelfServeUpgradeEnabled(r.getSelfServeUpgradeEnabled());
        if (r.getRequiresQuote() != null) p.setRequiresQuote(r.getRequiresQuote());
        if (r.getFulfilmentNotes() != null) p.setFulfilmentNotes(r.getFulfilmentNotes());

        String features = r.featuresJson();
        if (features != null) p.setFeatures(features);

        String entitlements = r.entitlementsJson();
        if (entitlements != null) p.setEntitlements(entitlements);

        // Recomputed from the resulting prices rather than trusted from the request,
        // so a price edited without touching the percentage cannot leave the two
        // disagreeing on an invoice.
        p.setAnnualDiscountPct(computeAnnualDiscount(p));
    }

    /**
     * Derives the annual discount from the actual prices. Returns the explicit value
     * only when there is no monthly price to derive from (a custom-priced plan).
     */
    private BigDecimal computeAnnualDiscount(OrgSubscription p) {
        BigDecimal monthly = p.getPriceMonthly();
        BigDecimal yearly = p.getPriceYearly();
        if (monthly == null || yearly == null || monthly.signum() <= 0) {
            return p.getAnnualDiscountPct();
        }
        BigDecimal list = monthly.multiply(BigDecimal.valueOf(12));
        return list.subtract(yearly)
                .multiply(BigDecimal.valueOf(100))
                .divide(list, 2, java.math.RoundingMode.HALF_UP);
    }

    private void validate(OrgSubscription p) {
        boolean custom = Boolean.TRUE.equals(p.getIsCustomPriced());
        if (!custom && p.getPriceMonthly() == null) {
            throw new BadRequestException(
                    "A plan needs a monthly price, or must be marked as custom priced.");
        }
        if (p.getPriceMonthly() != null && p.getPriceMonthly().signum() < 0) {
            throw BadRequestException.field("priceMonthly", "cannot be negative");
        }
        if (p.getPriceYearly() != null && p.getPriceYearly().signum() < 0) {
            throw BadRequestException.field("priceYearly", "cannot be negative");
        }
        rejectNegative("maxActiveStudents", p.getMaxActiveStudents());
        rejectNegative("maxFacultyAccounts", p.getMaxFacultyAccounts());
        rejectNegative("maxBranches", p.getMaxBranches());
        rejectNegative("maxOrganizations", p.getMaxOrganizations());
        rejectNegative("storageGb", p.getStorageGb());

        // Guard the pricing rule that keeps the seat add-on from undercutting the next
        // tier. Selling overage below the plan's own effective per-student rate makes
        // stacking seats cheaper than upgrading, which is exactly the trap the
        // original 15-40 band created for Platform Plus.
        if (p.getOverageStudentPrice() != null
                && p.getMaxActiveStudents() != null && p.getMaxActiveStudents() > 0
                && p.getPriceMonthly() != null && p.getPriceMonthly().signum() > 0) {
            BigDecimal effectiveRate = p.getPriceMonthly()
                    .divide(BigDecimal.valueOf(p.getMaxActiveStudents()), 2, java.math.RoundingMode.HALF_UP);
            if (p.getOverageStudentPrice().compareTo(effectiveRate) < 0) {
                throw new BadRequestException(String.format(
                        "Overage price %s per student is below this plan's own effective rate of %s "
                                + "(%s / %d students). Pricing overage under the plan rate makes buying extra "
                                + "seats cheaper than upgrading, so nobody would ever move up a tier.",
                        p.getOverageStudentPrice().toPlainString(), effectiveRate.toPlainString(),
                        p.getPriceMonthly().toPlainString(), p.getMaxActiveStudents()));
            }
        }
    }

    private void rejectNegative(String field, Integer value) {
        if (value != null && value < 0) {
            throw BadRequestException.field(field, "cannot be negative (leave it empty for unlimited)");
        }
    }

    /**
     * Derives a code for a new plan from the supplied code or the name. Codes are the
     * stable handle for application logic, so one is always assigned rather than
     * relying on the caller.
     */
    private String resolveNewCode(PlanRequest request) {
        String candidate = request.getCode() != null && !request.getCode().isBlank()
                ? request.getCode()
                : request.getName();
        String code = candidate.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]+", "_")
                .replaceAll("^_+|_+$", "");
        if (code.isEmpty()) {
            code = "PLAN";
        }
        if (code.length() > 40) {
            code = code.substring(0, 40);
        }
        if (!orgSubscriptionRepository.existsByCode(code)) {
            return code;
        }
        for (int i = 2; i < 100; i++) {
            String suffixed = (code.length() > 36 ? code.substring(0, 36) : code) + "_" + i;
            if (!orgSubscriptionRepository.existsByCode(suffixed)) {
                return suffixed;
            }
        }
        throw new BadRequestException("Could not derive a unique plan code from '" + candidate + "'.");
    }
}
