package com.institute.lms.controller;

import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.service.OrgSubscriptionService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

/**
 * CRUD for SaaS organization subscription plans (e.g. "Platform Only",
 * "Platform + Training Support"). Only super admins (ADMIN role) manage these.
 */
@RestController
@RequestMapping("/api/org-subscriptions")
public class OrgSubscriptionController {

    private final OrgSubscriptionService service;
    private final OrganizationRepository organizationRepository;
    private final UserContext userContext;

    private static final BigDecimal MAX_PRICE = new BigDecimal("999999999");

    public OrgSubscriptionController(OrgSubscriptionService service,
                                     OrganizationRepository organizationRepository,
                                     UserContext userContext) {
        this.service = service;
        this.organizationRepository = organizationRepository;
        this.userContext = userContext;
    }

    @GetMapping
    public ResponseEntity<?> getAll() {
        return ResponseEntity.ok(service.getAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@PathVariable Long id) {
        OrgSubscription sub = service.getById(id);
        if (sub == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(sub);
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required to manage org subscriptions");
        }
        String name = body.get("name");
        if (name == null || name.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Name is required"));
        }
        OrgSubscription saved = service.create(
                name,
                body.get("description"),
                parsePrice(body.get("price")),
                body.getOrDefault("period", "monthly"),
                body.getOrDefault("features", "[]"),
                body.containsKey("isActive") ? Boolean.parseBoolean(body.get("isActive")) : true,
                body.containsKey("isPopular") ? Boolean.parseBoolean(body.get("isPopular")) : false
        );
        return ResponseEntity.ok(saved);
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required to manage org subscriptions");
        }
        try {
            OrgSubscription updated = service.update(
                    id,
                    body.get("name"),
                    body.get("description"),
                    parsePrice(body.get("price")),
                    body.get("period"),
                    body.get("features"),
                    body.containsKey("isActive") ? Boolean.parseBoolean(body.get("isActive")) : null,
                    body.containsKey("isPopular") ? Boolean.parseBoolean(body.get("isPopular")) : null
            );
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required to manage org subscriptions");
        }
        // Prevent deleting a plan that is still in use by an organization.
        if (organizationRepository.findAll().stream().anyMatch(o -> o.getOrgSubscriptionId() != null
                && o.getOrgSubscriptionId().equals(id))) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "Cannot delete: plan is assigned to one or more organizations"));
        }
        service.delete(id);
        return ResponseEntity.ok().build();
    }

    private BigDecimal parsePrice(String raw) {
        if (raw == null || raw.isBlank()) return BigDecimal.ZERO;
        try {
            BigDecimal p = new BigDecimal(raw);
            return p.compareTo(BigDecimal.ZERO) < 0 || p.compareTo(MAX_PRICE) > 0 ? BigDecimal.ZERO : p;
        } catch (NumberFormatException e) {
            return BigDecimal.ZERO;
        }
    }
}