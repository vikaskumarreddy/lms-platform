package com.institute.lms.service;

import com.institute.lms.dto.subscription.AddonRequest;
import com.institute.lms.entity.PlanAddon;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.PlanAddonRepository;
import com.institute.lms.subscription.AddonCategory;
import com.institute.lms.subscription.AddonPricingModel;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.JsonUtils;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Manages the add-on catalog.
 *
 * <p>The validation here is the reason add-ons can be configured freely without
 * breaking enforcement: {@code incrementsLimitKey} and {@code grantsEntitlementKey}
 * are checked against the {@link LimitKey} and {@link Entitlement} enums on write, so
 * a typo becomes a 400 at configuration time rather than an add-on that a customer
 * pays for and that silently grants nothing.
 */
@Service
public class PlanAddonService {

    private final PlanAddonRepository planAddonRepository;

    public PlanAddonService(PlanAddonRepository planAddonRepository) {
        this.planAddonRepository = planAddonRepository;
    }

    /** Full catalog, including inactive entries, for the platform editor. */
    public List<PlanAddon> getAll() {
        return planAddonRepository.findAllByOrderByDisplayOrderAsc();
    }

    /** Active add-ons only, for tenant-facing lists. */
    public List<PlanAddon> getActive() {
        return planAddonRepository.findByIsActiveTrueOrderByDisplayOrderAsc();
    }

    /**
     * Active add-ons that may be attached to the given plan. An add-on with no
     * {@code appliesToPlanCodes} restriction is available everywhere; one that lists
     * codes is hidden from plans not in the list, so a branch add-on is never offered
     * to a single-branch tenant who has no feature to use it with.
     */
    public List<PlanAddon> getAvailableForPlan(String planCode) {
        return getActive().stream()
                .filter(a -> planCode == null || JsonUtils.listContains(a.getAppliesToPlanCodes(), planCode))
                .toList();
    }

    public Optional<PlanAddon> getByCode(String code) {
        return code == null ? Optional.empty() : planAddonRepository.findByCode(code);
    }

    public PlanAddon requireById(Long id) {
        return planAddonRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(ErrorCode.ADDON_NOT_FOUND,
                        "Add-on " + id + " was not found"));
    }

    public PlanAddon requireByCode(String code) {
        return getByCode(code).orElseThrow(() -> new ResourceNotFoundException(ErrorCode.ADDON_NOT_FOUND,
                "Add-on '" + code + "' was not found"));
    }

    /** Active add-ons that raise a given limit — used to suggest a fix in a quota error. */
    public List<PlanAddon> findRaising(LimitKey limitKey) {
        return limitKey == null
                ? List.of()
                : planAddonRepository.findByIncrementsLimitKeyAndIsActiveTrue(limitKey.name());
    }

    /** Active add-ons that grant a given entitlement — used the same way for feature blocks. */
    public List<PlanAddon> findGranting(Entitlement entitlement) {
        return entitlement == null
                ? List.of()
                : planAddonRepository.findByGrantsEntitlementKeyAndIsActiveTrue(entitlement.name());
    }

    @Transactional
    public PlanAddon create(AddonRequest request) {
        if (request.getName() == null || request.getName().isBlank()) {
            throw BadRequestException.field("name", "is required");
        }
        PlanAddon addon = new PlanAddon();
        addon.setCode(resolveNewCode(request));
        apply(request, addon);
        validate(addon);
        return planAddonRepository.save(addon);
    }

    @Transactional
    public PlanAddon update(Long id, AddonRequest request) {
        PlanAddon addon = requireById(id);
        if (request.getCode() != null && !request.getCode().equalsIgnoreCase(addon.getCode())) {
            throw new BadRequestException("An add-on's code cannot be changed once created; "
                    + "purchased add-ons reference '" + addon.getCode() + "'.");
        }
        apply(request, addon);
        validate(addon);
        return planAddonRepository.save(addon);
    }

    @Transactional
    public void delete(Long id) {
        PlanAddon addon = requireById(id);
        // Purchased add-ons keep a frozen copy of code and price, so removing a
        // definition does not corrupt billing history — but deactivating is still the
        // safer default, and is what the UI offers.
        planAddonRepository.delete(addon);
    }

    /**
     * Validates and clamps a quantity against the add-on's rules, so callers get a
     * usable number or a clear explanation rather than a silently-rounded charge.
     */
    public int validateQuantity(PlanAddon addon, Integer requested) {
        if (!addon.isQuantified()) {
            return 1;
        }
        int qty = requested != null ? requested : addon.getMinQty();
        if (qty < addon.getMinQty()) {
            throw new BadRequestException(ErrorCode.ADDON_QUANTITY_INVALID, String.format(
                    "%s is sold in units of at least %d %s.",
                    addon.getName(), addon.getMinQty(), plural(addon)));
        }
        if (addon.getMaxQty() != null && qty > addon.getMaxQty()) {
            throw new BadRequestException(ErrorCode.ADDON_QUANTITY_INVALID, String.format(
                    "%s can be bought up to %d %s at a time.",
                    addon.getName(), addon.getMaxQty(), plural(addon)));
        }
        int increment = addon.getQtyIncrement() != null && addon.getQtyIncrement() > 0
                ? addon.getQtyIncrement() : 1;
        if (increment > 1 && qty % increment != 0) {
            throw new BadRequestException(ErrorCode.ADDON_QUANTITY_INVALID, String.format(
                    "%s is sold in blocks of %d %s — %d is not a whole number of blocks.",
                    addon.getName(), increment, plural(addon), qty));
        }
        return qty;
    }

    private String plural(PlanAddon addon) {
        String unit = addon.getUnitLabel();
        return unit != null ? unit + "s" : "units";
    }

    private void apply(AddonRequest r, PlanAddon a) {
        if (r.getName() != null) a.setName(r.getName().trim());
        if (r.getDescription() != null) a.setDescription(r.getDescription());

        if (r.getCategory() != null) a.setCategory(parseCategory(r.getCategory()));
        if (r.getPricingModel() != null) a.setPricingModel(parsePricingModel(r.getPricingModel()));

        if (r.getUnitLabel() != null) a.setUnitLabel(r.getUnitLabel());
        if (r.getUnitPriceMin() != null) a.setUnitPriceMin(r.getUnitPriceMin());
        if (r.getUnitPriceMax() != null) a.setUnitPriceMax(r.getUnitPriceMax());
        if (r.getDefaultUnitPrice() != null) a.setDefaultUnitPrice(r.getDefaultUnitPrice());

        if (r.getMinQty() != null) a.setMinQty(r.getMinQty());
        if (r.getMaxQty() != null) a.setMaxQty(r.getMaxQty());
        if (r.getQtyIncrement() != null) a.setQtyIncrement(r.getQtyIncrement());

        if (r.getIncrementsLimitKey() != null) {
            a.setIncrementsLimitKey(normaliseLimitKey(r.getIncrementsLimitKey()));
        }
        if (r.getGrantsEntitlementKey() != null) {
            a.setGrantsEntitlementKey(normaliseEntitlementKey(r.getGrantsEntitlementKey()));
        }

        String applies = r.appliesToPlanCodesJson();
        if (applies != null) a.setAppliesToPlanCodes(applies);

        if (r.getRequiresQuote() != null) a.setRequiresQuote(r.getRequiresQuote());
        if (r.getFulfilmentNotes() != null) a.setFulfilmentNotes(r.getFulfilmentNotes());

        if (r.getHsnSacCode() != null) a.setHsnSacCode(r.getHsnSacCode());
        if (r.getGstRatePct() != null) a.setGstRatePct(r.getGstRatePct());
        if (r.getTaxInclusive() != null) a.setTaxInclusive(r.getTaxInclusive());

        if (r.getIsActive() != null) a.setIsActive(r.getIsActive());
        if (r.getDisplayOrder() != null) a.setDisplayOrder(r.getDisplayOrder());
    }

    private void validate(PlanAddon a) {
        if (a.getUnitPriceMin() != null && a.getUnitPriceMax() != null
                && a.getUnitPriceMin().compareTo(a.getUnitPriceMax()) > 0) {
            throw new BadRequestException("The minimum price cannot be greater than the maximum price.");
        }
        for (BigDecimal price : List.of(
                a.getUnitPriceMin() != null ? a.getUnitPriceMin() : BigDecimal.ZERO,
                a.getUnitPriceMax() != null ? a.getUnitPriceMax() : BigDecimal.ZERO,
                a.getDefaultUnitPrice() != null ? a.getDefaultUnitPrice() : BigDecimal.ZERO)) {
            if (price.signum() < 0) {
                throw new BadRequestException("Add-on prices cannot be negative.");
            }
        }
        if (a.getDefaultUnitPrice() != null) {
            if (a.getUnitPriceMin() != null && a.getDefaultUnitPrice().compareTo(a.getUnitPriceMin()) < 0) {
                throw new BadRequestException("The default price is below the minimum of the agreed band.");
            }
            if (a.getUnitPriceMax() != null && a.getDefaultUnitPrice().compareTo(a.getUnitPriceMax()) > 0) {
                throw new BadRequestException("The default price is above the maximum of the agreed band.");
            }
        }
        if (a.getMinQty() != null && a.getMinQty() < 1) {
            throw BadRequestException.field("minQty", "must be at least 1");
        }
        if (a.getMaxQty() != null && a.getMinQty() != null && a.getMaxQty() < a.getMinQty()) {
            throw new BadRequestException("The maximum quantity cannot be below the minimum quantity.");
        }
        // A quoted add-on with no list price is expected; a non-quoted one with no
        // price cannot be invoiced, so catch it here rather than at billing time.
        if (a.getPricingModel() != AddonPricingModel.QUOTED
                && a.getDefaultUnitPrice() == null && !Boolean.TRUE.equals(a.getRequiresQuote())) {
            throw new BadRequestException(
                    "A non-quoted add-on needs a default price, otherwise it cannot be invoiced.");
        }
    }

    private AddonCategory parseCategory(String raw) {
        try {
            return AddonCategory.valueOf(raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("Unknown add-on category '" + raw + "'. Expected one of "
                    + java.util.Arrays.toString(AddonCategory.values()));
        }
    }

    private AddonPricingModel parsePricingModel(String raw) {
        try {
            return AddonPricingModel.valueOf(raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new BadRequestException("Unknown pricing model '" + raw + "'. Expected one of "
                    + java.util.Arrays.toString(AddonPricingModel.values()));
        }
    }

    /**
     * Checked against the enum so a mistyped key fails at configuration time. An
     * add-on that claims to raise "MAX_STUDENTS" would otherwise be sold, invoiced,
     * and grant nothing at all.
     */
    private String normaliseLimitKey(String raw) {
        if (raw.isBlank()) {
            return null;
        }
        LimitKey key = LimitKey.fromKey(raw);
        if (key == null) {
            throw new BadRequestException("Unknown limit key '" + raw
                    + "'. An add-on can only raise a limit the platform actually enforces.");
        }
        return key.name();
    }

    private String normaliseEntitlementKey(String raw) {
        if (raw.isBlank()) {
            return null;
        }
        Entitlement entitlement = Entitlement.fromKey(raw);
        if (entitlement == null) {
            throw new BadRequestException("Unknown entitlement key '" + raw
                    + "'. An add-on can only grant a feature the platform recognises.");
        }
        return entitlement.name();
    }

    private String resolveNewCode(AddonRequest request) {
        String candidate = request.getCode() != null && !request.getCode().isBlank()
                ? request.getCode()
                : request.getName();
        String code = candidate.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]+", "_")
                .replaceAll("^_+|_+$", "");
        if (code.isEmpty()) {
            code = "ADDON";
        }
        if (code.length() > 60) {
            code = code.substring(0, 60);
        }
        if (!planAddonRepository.existsByCode(code)) {
            return code;
        }
        for (int i = 2; i < 100; i++) {
            String suffixed = (code.length() > 56 ? code.substring(0, 56) : code) + "_" + i;
            if (!planAddonRepository.existsByCode(suffixed)) {
                return suffixed;
            }
        }
        throw new BadRequestException("Could not derive a unique add-on code from '" + candidate + "'.");
    }
}
