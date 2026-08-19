package com.institute.lms.controller;

import com.institute.lms.dto.subscription.PlanRequest;
import com.institute.lms.dto.subscription.PlanResponse;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.subscription.Entitlement;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * CRUD for the platform plan catalog — Platform, Platform Plus, Managed Academy,
 * Enterprise and the assisted Pilot. Only the platform super admin manages these.
 *
 * <p>Reading the catalog is open to any authenticated admin, because a tenant admin
 * needs the plan cards to render their own Account page. Writing is super-admin only.
 *
 * <p>The path stays {@code /api/org-subscriptions} so the existing plan editor keeps
 * working while the richer UI is built.
 */
@RestController
@RequestMapping("/api/org-subscriptions")
public class OrgSubscriptionController {

    private final OrgSubscriptionService service;
    private final UserContext userContext;

    public OrgSubscriptionController(OrgSubscriptionService service, UserContext userContext) {
        this.service = service;
        this.userContext = userContext;
    }

    @GetMapping
    public List<PlanResponse> getAll() {
        boolean superAdmin = userContext.isAdmin();
        // A tenant admin only ever needs the publicly offered plans; the full catalog
        // includes retired and internal entries that are not theirs to see.
        List<OrgSubscription> plans = superAdmin ? service.getAll() : service.getPublicPlans();
        List<PlanResponse> out = new ArrayList<>(plans.size());
        for (OrgSubscription plan : plans) {
            Long inUse = superAdmin ? service.countOrganizationsUsing(plan.getId()) : null;
            PlanResponse response = PlanResponse.from(plan, inUse);
            if (!superAdmin) {
                // Delivery notes are internal guidance, including caveats about work
                // the platform cannot currently do. Not for tenant eyes.
                response.setFulfilmentNotes(null);
            }
            out.add(response);
        }
        return out;
    }

    @GetMapping("/{id}")
    public ResponseEntity<PlanResponse> getById(@PathVariable Long id) {
        OrgSubscription plan = service.requireById(id);
        Long inUse = userContext.isAdmin() ? service.countOrganizationsUsing(id) : null;
        return ResponseEntity.ok(PlanResponse.from(plan, inUse));
    }

    @GetMapping("/by-code/{code}")
    public ResponseEntity<PlanResponse> getByCode(@PathVariable String code) {
        return ResponseEntity.ok(PlanResponse.from(service.requireByCode(code)));
    }

    @PostMapping
    public ResponseEntity<PlanResponse> create(@RequestBody PlanRequest request) {
        userContext.requireSuperAdmin();
        OrgSubscription saved = service.create(request);
        return ResponseEntity.ok(PlanResponse.from(saved, 0L));
    }

    @PutMapping("/{id}")
    public ResponseEntity<PlanResponse> update(@PathVariable Long id, @RequestBody PlanRequest request) {
        userContext.requireSuperAdmin();
        OrgSubscription saved = service.update(id, request);
        return ResponseEntity.ok(PlanResponse.from(saved, service.countOrganizationsUsing(id)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> delete(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        service.delete(id);
        return ResponseEntity.ok(Map.of("message", "Plan deleted"));
    }

    /**
     * The vocabulary the plan editor needs to render its limits and entitlements
     * panels: every {@link LimitKey} and {@link Entitlement} the platform actually
     * enforces, with display labels and categories.
     *
     * <p>Serving this from the enums means the editor can never offer a feature key
     * that enforcement does not understand — the failure mode that would otherwise
     * produce plans selling features nothing checks.
     */
    @GetMapping("/schema")
    public Map<String, Object> schema() {
        userContext.requireOrgAdmin();

        List<Map<String, Object>> limits = new ArrayList<>();
        for (LimitKey key : LimitKey.values()) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("key", key.name());
            m.put("dbColumn", key.getDbColumn());
            m.put("label", key.getPluralLabel());
            m.put("singularLabel", key.getSingularLabel());
            m.put("errorCode", key.getErrorCode().name());
            limits.add(m);
        }

        List<Map<String, Object>> entitlements = new ArrayList<>();
        for (Entitlement e : Entitlement.values()) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("key", e.name());
            m.put("label", e.getLabel());
            m.put("category", e.getCategory().name());
            m.put("categoryLabel", e.getCategory().getLabel());
            m.put("valueType", e.getValueType().name());
            m.put("salesQualified", e.isSalesQualified());
            entitlements.add(m);
        }

        List<Map<String, Object>> categories = new ArrayList<>();
        for (Entitlement.Category c : Entitlement.Category.values()) {
            categories.add(Map.of("key", c.name(), "label", c.getLabel()));
        }

        return Map.of(
                "limits", limits,
                "entitlements", entitlements,
                "entitlementCategories", categories,
                "unlimitedSentinel", LimitKey.UNLIMITED
        );
    }
}
