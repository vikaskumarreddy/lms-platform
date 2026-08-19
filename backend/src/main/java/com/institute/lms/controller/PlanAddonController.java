package com.institute.lms.controller;

import com.institute.lms.dto.subscription.AddonRequest;
import com.institute.lms.dto.subscription.AddonResponse;
import com.institute.lms.entity.PlanAddon;
import com.institute.lms.service.PlanAddonService;
import com.institute.lms.subscription.AddonCategory;
import com.institute.lms.subscription.AddonPricingModel;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * CRUD for the add-on catalog. Reading is open to any admin (tenants browse
 * available add-ons from their Account page); writing is super-admin only.
 */
@RestController
@RequestMapping("/api/plan-addons")
public class PlanAddonController {

    private final PlanAddonService service;
    private final UserContext userContext;

    public PlanAddonController(PlanAddonService service, UserContext userContext) {
        this.service = service;
        this.userContext = userContext;
    }

    /**
     * @param planCode when supplied, filters to add-ons attachable to that plan, so a
     *                 tenant is never offered capacity for a feature their plan lacks
     */
    @GetMapping
    public List<AddonResponse> getAll(@RequestParam(required = false) String planCode) {
        boolean superAdmin = userContext.isAdmin();
        List<PlanAddon> addons;
        if (superAdmin && planCode == null) {
            addons = service.getAll();
        } else {
            addons = service.getAvailableForPlan(planCode);
        }
        List<AddonResponse> out = new ArrayList<>(addons.size());
        for (PlanAddon addon : addons) {
            out.add(AddonResponse.from(addon, superAdmin));
        }
        return out;
    }

    @GetMapping("/{id}")
    public ResponseEntity<AddonResponse> getById(@PathVariable Long id) {
        return ResponseEntity.ok(AddonResponse.from(service.requireById(id), userContext.isAdmin()));
    }

    @PostMapping
    public ResponseEntity<AddonResponse> create(@RequestBody AddonRequest request) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(AddonResponse.from(service.create(request), true));
    }

    @PutMapping("/{id}")
    public ResponseEntity<AddonResponse> update(@PathVariable Long id, @RequestBody AddonRequest request) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(AddonResponse.from(service.update(id, request), true));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> delete(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        service.delete(id);
        return ResponseEntity.ok(Map.of("message", "Add-on deleted"));
    }

    /** Categories and pricing models the add-on editor offers, straight from the enums. */
    @GetMapping("/schema")
    public Map<String, Object> schema() {
        userContext.requireOrgAdmin();

        List<Map<String, Object>> categories = new ArrayList<>();
        for (AddonCategory c : AddonCategory.values()) {
            categories.add(Map.of("key", c.name(), "label", c.getLabel()));
        }

        List<Map<String, Object>> models = new ArrayList<>();
        for (AddonPricingModel m : AddonPricingModel.values()) {
            models.add(Map.of(
                    "key", m.name(),
                    "label", m.getLabel(),
                    "recurring", m.isRecurring(),
                    "quantified", m.isQuantified()));
        }

        return Map.of("categories", categories, "pricingModels", models);
    }
}
