package com.institute.lms.controller;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.User;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.OrgSubscriptionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.OrganizationService;
import com.institute.lms.service.subscription.SubscriptionLifecycleService;
import com.institute.lms.subscription.BillingCycle;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import com.institute.lms.repository.SubscriptionPlanRepository;

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
    private final SubscriptionPlanRepository subscriptionPlanRepository;

    public OrganizationController(OrganizationService organizationService,
                                  OrganizationRepository organizationRepository,
                                  OrgSubscriptionRepository orgSubscriptionRepository,
                                  UserRepository userRepository,
                                  PasswordEncoder passwordEncoder,
                                  UserContext userContext,
                                  OrganizationContext organizationContext,
                                  SubscriptionPlanRepository subscriptionPlanRepository) {
        this.organizationService = organizationService;
        this.organizationRepository = organizationRepository;
        this.orgSubscriptionRepository = orgSubscriptionRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.userContext = userContext;
        this.organizationContext = organizationContext;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
    }


    /**
     * All organizations, mapped through {@link #toOrgMap} so the list carries the same
     * fields as the single-organization endpoints — plan name, effective status and the
     * billing details. Returning raw entities here left the UI without the plan name it
     * displays, and without the GST fields the edit modal needs to round-trip.
     */
    @GetMapping
    public List<Map<String, Object>> getAll() {
        userContext.requireSuperAdmin();
        return organizationService.getAllOrganizations().stream()
                .map(this::toOrgMap)
                .toList();
    }

    @GetMapping("/current")
    public ResponseEntity<Map<String, Object>> getCurrentOrganization() {
        Organization org = organizationService.getCurrentOrganization();
        if (org == null) {
            return ResponseEntity.badRequest().build();
        }
        return ResponseEntity.ok(toOrgMap(org));
    }

    @GetMapping("/public-info")
    public ResponseEntity<Map<String, Object>> getPublicInfo(@RequestParam(value = "slug", required = false) String slug) {
        Organization org = null;
        if (slug != null && !slug.isBlank()) {
            org = organizationRepository.findBySlug(slug).orElse(null);
        }
        if (org == null) {
            org = organizationService.getCurrentOrganization();
        }
        if (org == null) {
            List<Organization> all = organizationRepository.findAll();
            if (!all.isEmpty()) org = all.get(0);
        }
        if (org == null) {
            return ResponseEntity.notFound().build();
        }
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("id", org.getId());
        res.put("name", org.getName());
        res.put("slug", org.getSlug());
        res.put("logoUrl", org.getLogoUrl());
        res.put("theme", resolveTheme(org));
        res.put("settings", org.getSettings());
        try {
            res.put("subscriptionPlans", subscriptionPlanRepository.findActiveByOrgIdNative(org.getId()));
        } catch (Exception ignored) {}
        return ResponseEntity.ok(res);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getById(@PathVariable Long id) {
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(toOrgMap(org));
    }

    /**
     * Creates an organization and, when a plan is chosen, starts its subscription term.
     *
     * <p>The body is typed {@code Map<String,Object>} rather than {@code Map<String,String>}
     * because the payload now carries numbers and a nested {@code limitOverrides} object —
     * the previous string-only binding could not express either.
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();

        String name = str(body.get("name"));
        String slug = str(body.get("slug"));
        if (name == null || name.isBlank()) {
            throw BadRequestException.field("name", "is required");
        }
        if (slug == null || slug.isBlank()) {
            throw BadRequestException.field("slug", "is required");
        }

        Long planId = asLong(body.get("planId"));
        Long orgSubscriptionId = asLong(body.get("orgSubscriptionId"));

        Organization org = organizationService.createOrganization(
                name, slug, str(body.get("domain")), planId, orgSubscriptionId,
                readSubscribeOptions(body));

        // Billing identity is captured at creation so an invoice can be raised later
        // without going back to the customer for a GSTIN.
        organizationService.updateBillingDetails(org.getId(), billingFields(body));

        if (body.containsKey("category")) {
            organizationService.updateCategory(org.getId(), str(body.get("category")));
        }
        if (body.containsKey("activeGateway")) {
            organizationService.updateActiveGateway(org.getId(), str(body.get("activeGateway")));
        }

        return ResponseEntity.ok(toOrgMap(
                organizationRepository.findById(org.getId()).orElse(org)));
    }

    /** Reads the subscription terms from a create/update payload. */
    private SubscriptionLifecycleService.SubscribeOptions readSubscribeOptions(Map<String, Object> body) {
        SubscriptionLifecycleService.SubscribeOptions options =
                new SubscriptionLifecycleService.SubscribeOptions();
        User actor = userContext.currentUser();
        options.actor = actor != null ? actor.getEmail() : "platform-admin";

        if (body.get("billingCycle") != null) {
            options.billingCycle = BillingCycle.fromName(body.get("billingCycle").toString());
        }
        if (body.get("agreedPrice") != null && !body.get("agreedPrice").toString().isBlank()) {
            options.agreedPrice = new java.math.BigDecimal(body.get("agreedPrice").toString());
        }
        options.poNumber = str(body.get("poNumber"));
        options.salesOwner = str(body.get("salesOwner"));

        Object overrides = body.get("limitOverrides");
        if (overrides instanceof Map<?, ?> raw && !raw.isEmpty()) {
            Map<LimitKey, Long> parsed = new LinkedHashMap<>();
            raw.forEach((key, value) -> {
                LimitKey limitKey = LimitKey.fromKey(String.valueOf(key));
                if (limitKey != null && value != null) {
                    parsed.put(limitKey, asLong(value));
                }
            });
            options.limitOverrides = parsed;
        }
        return options;
    }

    /** Extracts only the billing/contact keys actually present, so absent ones stay untouched. */
    private Map<String, String> billingFields(Map<String, Object> body) {
        Map<String, String> fields = new LinkedHashMap<>();
        for (String key : List.of("legalName", "gstin", "pan", "billingEmail", "billingPhone",
                "billingAddress", "city", "stateCode", "placeOfSupply", "pincode", "country",
                "contactPerson", "poNumber", "salesOwner", "notes")) {
            if (body.containsKey(key)) {
                fields.put(key, str(body.get(key)));
            }
        }
        return fields;
    }

    private String str(Object value) {
        return value != null ? value.toString() : null;
    }

    private Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        String raw = value.toString().trim();
        if (raw.isEmpty()) {
            return null;
        }
        try {
            return Long.parseLong(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * Updates an organization. Absent keys are left untouched.
     *
     * <p>Two things changed here. {@code isActive} no longer defaults to {@code true}
     * when the key is missing — that quietly reactivated suspended tenants on any
     * partial update. And exceptions are no longer swallowed into a bare 404: a
     * validation failure now reaches the caller as itself, rather than claiming the
     * organization does not exist.
     */
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> update(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();

        Boolean isActive = body.containsKey("isActive")
                ? Boolean.parseBoolean(String.valueOf(body.get("isActive"))) : null;

        // The same subscription terms the create form sends — billing cycle, agreed
        // price, PO, negotiated limits — so assigning or changing a plan from the editor
        // starts a properly-termed subscription rather than only setting a column.
        Organization org = organizationService.updateOrganization(
                id, str(body.get("name")), str(body.get("slug")), str(body.get("domain")),
                isActive, asLong(body.get("planId")), asLong(body.get("orgSubscriptionId")),
                str(body.get("status")), parseDate(str(body.get("purchaseDate"))),
                parseDate(str(body.get("expiryDate"))), readSubscribeOptions(body));

        Map<String, String> billing = billingFields(body);
        if (!billing.isEmpty()) {
            org = organizationService.updateBillingDetails(id, billing);
        }
        if (body.containsKey("category")) {
            org = organizationService.updateCategory(id, str(body.get("category")));
        }
        if (body.containsKey("activeGateway")) {
            org = organizationService.updateActiveGateway(id, str(body.get("activeGateway")));
        }
        return ResponseEntity.ok(toOrgMap(org));
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

    /**
     * The org's effective theme: {@link com.institute.lms.util.ThemeDefaults#defaults()}
     * with any customized keys from {@code settings.theme} layered on top.
     *
     * <p>This is what makes theming backward compatible — an org (e.g. Axisora) that has
     * never called the theme endpoint has no {@code theme} key in its settings JSON at all,
     * so every key here falls back to the original teal palette baked into styles.css.
     */
    private Map<String, String> resolveTheme(Organization org) {
        Map<String, String> resolved = new LinkedHashMap<>(com.institute.lms.util.ThemeDefaults.defaults());
        Map<String, Object> settings = com.institute.lms.util.JsonUtils.readMap(org.getSettings());
        Object rawTheme = settings.get("theme");
        if (rawTheme instanceof Map<?, ?> overrides) {
            overrides.forEach((k, v) -> {
                if (k != null && v != null) {
                    resolved.put(String.valueOf(k), String.valueOf(v));
                }
            });
        }
        return resolved;
    }

    /**
     * Replaces the org's custom theme overrides (CSS variable name -> color value).
     * Only org admins (super admin or the tenant's own INSTITUTE_ADMIN/ADMIN) can change it,
     * same audience as {@link #updateSettings}. An empty body resets the org back to the
     * built-in default palette.
     */
    @PutMapping("/{id}/theme")
    public ResponseEntity<Map<String, Object>> updateTheme(@PathVariable Long id,
                                                            @RequestBody Map<String, String> body) {
        userContext.requireOrgAdmin();
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) {
            return ResponseEntity.notFound().build();
        }
        Map<String, Object> updates = new LinkedHashMap<>();
        updates.put("theme", body == null ? Map.of() : body);
        organizationService.updateOrgSettings(id, updates);
        Organization saved = organizationRepository.findById(id).orElse(org);
        return ResponseEntity.ok(toOrgMap(saved));
    }

    /**
     * Updates the registration page dynamic field configuration in organization settings.
     */
    @PutMapping("/{id}/registration-fields")
    public ResponseEntity<Map<String, Object>> updateRegistrationFields(@PathVariable Long id,
                                                                        @RequestBody Map<String, Object> body) {
        userContext.requireOrgAdmin();
        Organization org = organizationRepository.findById(id).orElse(null);
        if (org == null) {
            return ResponseEntity.notFound().build();
        }
        Map<String, Object> updates = new LinkedHashMap<>();
        updates.put("registrationFormConfig", body == null ? Map.of() : body);
        organizationService.updateOrgSettings(id, updates);
        Organization saved = organizationRepository.findById(id).orElse(org);
        return ResponseEntity.ok(toOrgMap(saved));
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
        map.put("category", org.getCategory() != null ? org.getCategory().name() : "OTHER");
        map.put("activeGateway", org.getActiveGateway() != null ? org.getActiveGateway().name() : "RAZORPAY");
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
        map.put("theme", resolveTheme(org));
        map.put("createdAt", org.getCreatedAt());
        map.put("updatedAt", org.getUpdatedAt());

        // Billing identity and sales context, so the edit modal can round-trip them
        // rather than blanking fields it never received.
        map.put("legalName", org.getLegalName());
        map.put("gstin", org.getGstin());
        map.put("pan", org.getPan());
        map.put("billingEmail", org.getBillingEmail());
        map.put("billingPhone", org.getBillingPhone());
        map.put("billingAddress", org.getBillingAddress());
        map.put("city", org.getCity());
        map.put("stateCode", org.getStateCode());
        map.put("placeOfSupply", org.getPlaceOfSupply());
        map.put("pincode", org.getPincode());
        map.put("country", org.getCountry());
        map.put("contactPerson", org.getContactPerson());
        map.put("poNumber", org.getPoNumber());
        map.put("salesOwner", org.getSalesOwner());
        map.put("storageBytesUsed", org.getStorageBytesUsed());
        return map;
    }

    /**
     * Creates an organization admin (INSTITUTE_ADMIN) for a specific organization.
     * Only super admins (ADMIN role) can create org admins.
     *
     * <p>Uses native JDBC queries so the super-admin thread's Hibernate session
     * (bound to the "-1" sentinel tenant) does not trigger Hibernate's
     * {@code assigned tenant id differs from current tenant id} validation when
     * the entity's {@code organizationId} differs from the session tenant.</p>
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

        try {
            // Native existence check — bypasses the "-1" tenant discriminator so
            // the super admin can see the target org's existing users.
            if (userRepository.existsAdminEmailInOrg(id, email)) {
                return ResponseEntity.badRequest().body(Map.of("error", "Email already exists in this organization"));
            }

            // Native INSERT — bypasses JPA's @TenantId validation entirely,
            // which would otherwise reject this entity because the super-admin
            // session is bound to tenant "-1" but the row's org is the target id.
            int inserted = userRepository.insertOrganizationAdmin(
                    id,
                    email,
                    passwordEncoder.encode(password),
                    name,
                    phone,
                    User.UserRole.INSTITUTE_ADMIN.name());

            if (inserted != 1) {
                return ResponseEntity.badRequest().body(Map.of("error", "Failed to create organization admin"));
            }

            // Read back the generated id (identity column) so the response has it.
            Long newId = userRepository.findOrgAdminIdByEmail(id, email);
            if (newId == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Failed to create organization admin"));
            }

            return ResponseEntity.ok(Map.of(
                    "id", newId,
                    "email", email,
                    "name", name,
                    "role", "INSTITUTE_ADMIN",
                    "organizationId", id,
                    "message", "Organization admin created successfully"
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
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
        if (!organizationRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        // Native read — bypasses Hibernate's @TenantId DISCRIMINATOR so the
        // super-admin's "-1" session tenant can still see the target org's rows.
        User admin = userRepository.findOrgAdminById(id, adminId).orElse(null);
        if (admin == null || Boolean.TRUE.equals(admin.getIsGhost())) {
            return ResponseEntity.notFound().build();
        }

        String name = body.get("name") != null && !body.get("name").isBlank() ? body.get("name") : null;
        String phone = body.containsKey("phone") ? body.get("phone") : null;
        Boolean isActive = body.containsKey("isActive") ? Boolean.parseBoolean(body.get("isActive")) : null;
        String encodedPassword = body.get("password") != null && !body.get("password").isBlank()
                ? passwordEncoder.encode(body.get("password")) : null;

        int updated = userRepository.updateOrganizationAdmin(id, adminId, name, phone, encodedPassword, isActive);
        if (updated == 0) {
            return ResponseEntity.notFound().build();
        }

        // Re-read via native query so the response reflects the persisted state.
        User saved = userRepository.findOrgAdminById(id, adminId).orElse(admin);
        return ResponseEntity.ok(Map.of(
                "id", saved.getId(),
                "email", saved.getEmail() != null ? saved.getEmail() : "",
                "name", saved.getName() != null ? saved.getName() : "",
                "phone", saved.getPhone() != null ? saved.getPhone() : "",
                "role", "INSTITUTE_ADMIN",
                "organizationId", id,
                "message", "Organization admin updated successfully"
        ));
    }

    /**
     * Deletes an existing organization admin (INSTITUTE_ADMIN) for a specific organization.
     * Only super admins (ADMIN role) can delete org admins.
     *
     * <p>Uses native JDBC to bypass Hibernate's @TenantId DISCRIMINATOR so the
     * super-admin's "-1" session tenant can still reach the target org's rows.</p>
     */
    @DeleteMapping("/{id}/admin/{adminId}")
    public ResponseEntity<?> deleteOrgAdmin(@PathVariable Long id,
                                            @PathVariable Long adminId) {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Super Admin role required to delete org admins");
        }
        if (!organizationRepository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        // Native check that the target user is a real admin in this org.
        User admin = userRepository.findOrgAdminById(id, adminId).orElse(null);
        if (admin == null || Boolean.TRUE.equals(admin.getIsGhost())) {
            return ResponseEntity.notFound().build();
        }

        int deleted = userRepository.deleteOrganizationAdmin(id, adminId);
        if (deleted == 0) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of("message", "Organization admin deleted successfully"));
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
                .findNonGhostAdminsByOrganizationId(id, User.UserRole.INSTITUTE_ADMIN.name())
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
