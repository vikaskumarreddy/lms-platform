package com.institute.lms.controller;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.User;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.OrgSubscriptionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.OrganizationService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/organizations")
public class OrganizationController {

    private final OrganizationService organizationService;
    private final OrganizationRepository organizationRepository;
    private final OrgSubscriptionRepository orgSubscriptionRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserContext userContext;
    private final OrganizationContext organizationContext;

    public OrganizationController(OrganizationService organizationService,
                                  OrganizationRepository organizationRepository,
                                  OrgSubscriptionRepository orgSubscriptionRepository,
                                  UserRepository userRepository,
                                  PasswordEncoder passwordEncoder,
                                  UserContext userContext,
                                  OrganizationContext organizationContext) {
        this.organizationService = organizationService;
        this.organizationRepository = organizationRepository;
        this.orgSubscriptionRepository = orgSubscriptionRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.userContext = userContext;
        this.organizationContext = organizationContext;
    }


    @GetMapping
    public List<Organization> getAll() {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        return organizationService.getAllOrganizations();
    }

    @GetMapping("/current")
    public ResponseEntity<Map<String, Object>> getCurrentOrganization() {
        Organization org = organizationService.getCurrentOrganization();
        if (org == null) {
            return ResponseEntity.badRequest().build();
        }
        return ResponseEntity.ok(toOrgMap(org));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getById(@PathVariable Long id) {
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(toOrgMap(org));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        String name = body.get("name");
        String slug = body.get("slug");
        String domain = body.get("domain");
        Long planId = body.get("planId") != null ? Long.valueOf(body.get("planId")) : null;
        Long orgSubscriptionId = body.get("orgSubscriptionId") != null && !body.get("orgSubscriptionId").isEmpty()
                ? Long.valueOf(body.get("orgSubscriptionId")) : null;
        if (name == null || slug == null) {
            return ResponseEntity.badRequest().build();
        }
                Organization org = organizationService.createOrganization(name, slug, domain, planId, orgSubscriptionId);
        return ResponseEntity.ok(toOrgMap(org));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> update(@PathVariable Long id, @RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        try {
            Boolean isActive = body.containsKey("isActive") ? Boolean.parseBoolean(body.get("isActive")) : true;
            Long planId = body.get("planId") != null && !body.get("planId").isEmpty()
                    ? Long.valueOf(body.get("planId")) : null;
            Long orgSubscriptionId = body.get("orgSubscriptionId") != null && !body.get("orgSubscriptionId").isEmpty()
                    ? Long.valueOf(body.get("orgSubscriptionId")) : null;
            Organization org = organizationService.updateOrganization(
                    id, body.get("name"), body.get("slug"), body.get("domain"), isActive, planId, orgSubscriptionId,
                    body.get("status"), parseDate(body.get("purchaseDate")), parseDate(body.get("expiryDate")));
            return ResponseEntity.ok(toOrgMap(org));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Renews an organization's subscription: reactivates it, resets the purchase date
     * to now, extends the expiry based on the assigned plan, and increments the renewal
     * counter. Only super admins (ADMIN role) can renew organizations.
     */
    @PostMapping("/{id}/renew")
    public ResponseEntity<Map<String, Object>> renew(@PathVariable Long id) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        try {
            Organization org = organizationService.renewOrganization(id);
            return ResponseEntity.ok(toOrgMap(org));
        } catch (RuntimeException e) {
            return ResponseEntity.notFound().build();
        }
    }

    /** Parses an ISO date-time string to LocalDateTime, returning null when absent/unparseable. */
    private LocalDateTime parseDate(String value) {
        if (value == null || value.isBlank()) return null;
        try {
            return LocalDateTime.parse(value);
        } catch (Exception e) {
            return null;
        }
    }

    /** Uploads a logo image for an organization and returns the logo URL. */
    @PostMapping("/{id}/logo")
    public ResponseEntity<Map<String, String>> uploadLogo(@PathVariable Long id,
                                                           @RequestPart("file") MultipartFile file) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        try {
            String logoUrl = organizationService.uploadLogo(id, file);
            return ResponseEntity.ok(Map.of("logoUrl", logoUrl));
        } catch (Exception e) {
            return ResponseEntity.badRequest().build();
        }
    }

    /** Updates organization settings as key-value pairs. */
    @PutMapping("/{id}/settings")
    public ResponseEntity<Map<String, Object>> updateSettings(@PathVariable Long id,
                                                                 @RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        String key = body.get("key");
        String value = body.get("value");
        if (key == null || value == null) {
            return ResponseEntity.badRequest().build();
        }
        organizationService.updateOrgSetting(id, key, value);
        Organization org = organizationRepository.findById(id).orElse(null);
        return ResponseEntity.ok(toOrgMap(org));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }
        organizationService.deleteOrganization(id);
        return ResponseEntity.ok().build();
    }

    private Map<String, Object> toOrgMap(Organization org) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", org.getId());
        map.put("name", org.getName());
        map.put("slug", org.getSlug());
        map.put("domain", org.getDomain());
        map.put("logoUrl", org.getLogoUrl());
        map.put("isActive", org.getIsActive());
        map.put("planId", org.getPlanId());
        map.put("orgSubscriptionId", org.getOrgSubscriptionId());
        String subName = null;
        if (org.getOrgSubscriptionId() != null) {
            subName = orgSubscriptionRepository.findById(org.getOrgSubscriptionId())
                    .map(OrgSubscription::getName).orElse(null);
        }
        map.put("orgSubscriptionName", subName);
        // Effective lifecycle status: once expiry_date passes, the org is EXPIRED even
        // if the stored status was never flipped, so the Renew action is always shown.
        boolean isExpired = org.getExpiryDate() != null && org.getExpiryDate().isBefore(LocalDateTime.now());
        String status = "EXPIRED".equalsIgnoreCase(org.getStatus()) || isExpired ? "EXPIRED" : "ACTIVE";
        map.put("status", status);
        map.put("isExpired", isExpired);
        map.put("purchaseDate", org.getPurchaseDate());
        map.put("expiryDate", org.getExpiryDate());
        map.put("renewalCount", org.getRenewalCount());
        map.put("settings", org.getSettings());
        map.put("createdAt", org.getCreatedAt());
        map.put("updatedAt", org.getUpdatedAt());
        return map;
    }

    /**
     * Creates an organization admin (INSTITUTE_ADMIN) for a specific organization.
     * Only super admins (ADMIN role) can create org admins.
     */
    @PostMapping("/{id}/admin")
    public ResponseEntity<Map<String, Object>> createOrgAdmin(@PathVariable Long id,
                                                               @RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Super Admin role required to create org admins");
        }

        String email = body.get("email");
        String name = body.get("name");
        String password = body.get("password");
        String phone = body.get("phone");

        if (email == null || name == null || password == null) {
            return ResponseEntity.badRequest().build();
        }

        // The platform ghost super-admin cannot be re-used as an ordinary tenant admin.
        if ("admin@axisora.com".equalsIgnoreCase(email)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Email already exists"));
        }

                // Organization is NOT a BaseEntity (no @TenantId), so existsById is safe
        // even when the super-admin thread carries the "-1" sentinel tenant.
        if (!organizationRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        // Fetch the org and set the tenant context so Hibernate's @TenantId
        // DISCRIMINATOR predicate matches the organizationId we are about to
        // write on the User entity. Without this the super-admin thread's "-1"
        // sentinel causes existsByOrganizationIdAndEmail to always return
        // false and userRepository.save to throw PropertyValueException.
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) {
            return ResponseEntity.notFound().build();
        }
        organizationContext.setCurrentOrganization(org);
        try {
            if (userRepository.existsByOrganizationIdAndEmail(id, email)) {
                return ResponseEntity.badRequest().body(Map.of("error", "Email already exists in this organization"));
            }

            // Create INSTITUTE_ADMIN user for this organization
            User admin = new User();
            admin.setEmail(email);
            admin.setName(name);
            admin.setPassword(passwordEncoder.encode(password));
            admin.setPhone(phone);
            admin.setRole(User.UserRole.INSTITUTE_ADMIN);
            admin.setIsActive(true);
            admin.setIsEmailVerified(false);
            admin.setOrganizationId(id);

            User savedAdmin = userRepository.save(admin);

            return ResponseEntity.ok(Map.of(
                    "id", savedAdmin.getId(),
                    "email", savedAdmin.getEmail(),
                    "name", savedAdmin.getName(),
                    "role", "INSTITUTE_ADMIN",
                    "organizationId", id,
                    "message", "Organization admin created successfully"
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } finally {
            organizationContext.clear();
        }
    }

    /**
     * Updates an existing organization admin (INSTITUTE_ADMIN) for a specific organization.
     * Only super admins (ADMIN role) can update org admins. The tenant context is
     * temporarily set to the target org so Hibernate's @TenantId DISCRIMINATOR matches
     * the User row we load/save (the super-admin thread otherwise carries the "-1"
     * sentinel tenant and would find/write nothing).
     */
    @PutMapping("/{id}/admin/{adminId}")
    public ResponseEntity<Map<String, Object>> updateOrgAdmin(@PathVariable Long id,
                                                              @PathVariable Long adminId,
                                                              @RequestBody Map<String, String> body) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Super Admin role required to update org admins");
        }
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) {
            return ResponseEntity.notFound().build();
        }
        organizationContext.setCurrentOrganization(org);
        try {
            User admin = userRepository.findById(adminId).orElse(null);
            if (admin == null || admin.getRole() != User.UserRole.INSTITUTE_ADMIN
                    || Boolean.TRUE.equals(admin.getIsGhost())) {
                return ResponseEntity.notFound().build();
            }
            if (body.get("name") != null && !body.get("name").isBlank()) {
                admin.setName(body.get("name"));
            }
            if (body.containsKey("phone")) {
                admin.setPhone(body.get("phone"));
            }
            if (body.containsKey("isActive")) {
                admin.setIsActive(Boolean.parseBoolean(body.get("isActive")));
            }
            if (body.get("password") != null && !body.get("password").isBlank()) {
                admin.setPassword(passwordEncoder.encode(body.get("password")));
            }
            User saved = userRepository.save(admin);
            return ResponseEntity.ok(Map.of(
                    "id", saved.getId(),
                    "email", saved.getEmail() != null ? saved.getEmail() : "",
                    "name", saved.getName() != null ? saved.getName() : "",
                    "phone", saved.getPhone() != null ? saved.getPhone() : "",
                    "role", "INSTITUTE_ADMIN",
                    "organizationId", id,
                    "message", "Organization admin updated successfully"
            ));
        } finally {
            organizationContext.clear();
        }
    }

    /**
     * Deletes an existing organization admin (INSTITUTE_ADMIN) for a specific organization.
     * Only super admins (ADMIN role) can delete org admins.
     */
    @DeleteMapping("/{id}/admin/{adminId}")
    public ResponseEntity<?> deleteOrgAdmin(@PathVariable Long id,
                                            @PathVariable Long adminId) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Super Admin role required to delete org admins");
        }
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) {
            return ResponseEntity.notFound().build();
        }
        organizationContext.setCurrentOrganization(org);
        try {
            User admin = userRepository.findById(adminId).orElse(null);
            if (admin == null || admin.getRole() != User.UserRole.INSTITUTE_ADMIN
                    || Boolean.TRUE.equals(admin.getIsGhost())) {
                return ResponseEntity.notFound().build();
            }
            userRepository.delete(admin);
            return ResponseEntity.ok(Map.of("message", "Organization admin deleted successfully"));
        } finally {
            organizationContext.clear();
        }
    }

    /**
     * Lists all organization admins (INSTITUTE_ADMIN) for a specific organization.
     * Only super admins (ADMIN role) can view this list.
     */
    @GetMapping("/{id}/admin")
    public ResponseEntity<List<Map<String, Object>>> listOrgAdmins(@PathVariable Long id) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Super Admin role required to view org admins");
        }
        if (!organizationRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
                List<Map<String, Object>> admins = userRepository
                .findNonGhostAdminsByOrganizationId(id, User.UserRole.INSTITUTE_ADMIN)
                .stream()
                .filter(u -> !Boolean.TRUE.equals(u.getIsGhost()))
                .map(u -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", u.getId());
                    m.put("name", u.getName());
                    m.put("email", u.getEmail());
                    m.put("phone", u.getPhone());
                    m.put("isActive", u.getIsActive());
                    return m;
                })
                .collect(java.util.stream.Collectors.toList());
        return ResponseEntity.ok(admins);
    }
}
