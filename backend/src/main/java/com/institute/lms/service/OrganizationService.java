package com.institute.lms.service;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.User;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.OrgSubscriptionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.subscription.SubscriptionLifecycleService;
import com.institute.lms.subscription.SubscriptionChangeReason;
import com.institute.lms.util.JsonUtils;
import com.institute.lms.util.OrganizationContext;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Service for managing tenant Organizations and their customizations
 * (logo uploads, settings, etc.).
 */
@Service
public class OrganizationService {

    private final OrganizationRepository organizationRepository;
    private final OrganizationContext organizationContext;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final OrgSubscriptionRepository orgSubscriptionRepository;
    private final SubscriptionLifecycleService lifecycleService;
    private final S3StorageService s3StorageService;

    public OrganizationService(OrganizationRepository organizationRepository,
                               OrganizationContext organizationContext,
                               UserRepository userRepository,
                               PasswordEncoder passwordEncoder,
                               OrgSubscriptionRepository orgSubscriptionRepository,
                               SubscriptionLifecycleService lifecycleService,
                               S3StorageService s3StorageService) {
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.orgSubscriptionRepository = orgSubscriptionRepository;
        this.lifecycleService = lifecycleService;
        this.s3StorageService = s3StorageService;
    }

    /** Returns all organizations (including expired/inactive so renew actions are possible). */
    public List<Organization> getAllOrganizations() {
        return organizationRepository.findAll();
    }

    /** Returns a single organization by ID. */
    public Organization getOrganizationById(Long id) {
        return organizationRepository.findById(id).orElse(null);
    }

    /** Returns the current tenant's organization. */
    public Organization getCurrentOrganization() {
        return organizationContext.getCurrentOrganization();
    }

    /**
     * Creates a new organization (tenant), auto-provisions the platform ghost
     * super-admin inside it, and — when a plan is chosen — starts a real subscription
     * term for it.
     *
     * <p>That last step is what makes the plan mean anything. Setting
     * {@code org_subscription_id} alone only points at a catalog row; a subscription
     * instance is what freezes the agreed limits and entitlements and gives enforcement
     * something to read. Without it the organization would resolve to no entitlements at
     * all and fail closed on its first action.
     *
     * @param options nullable; controls billing cycle, agreed price and sales metadata
     */
    public Organization createOrganization(String name, String slug, String domain, Long planId,
                                           Long orgSubscriptionId,
                                           SubscriptionLifecycleService.SubscribeOptions options) {
        Organization org = new Organization();
        org.setName(name);
        org.setSlug(slug);
        org.setDomain(domain);
        org.setPlanId(planId);
        org.setOrgSubscriptionId(orgSubscriptionId);
        org.setSettings("{}");
        org.setStatus("ACTIVE");
        org.setPurchaseDate(LocalDateTime.now());
        org.setExpiryDate(computeExpiry(LocalDateTime.now(), orgSubscriptionId));
        org.setRenewalCount(0);
        Organization saved = organizationRepository.save(org);

        ensureGhostAdmin(saved.getId());

        if (orgSubscriptionId != null) {
            SubscriptionLifecycleService.SubscribeOptions opts = options != null
                    ? options : new SubscriptionLifecycleService.SubscribeOptions();
            lifecycleService.subscribe(saved.getId(), orgSubscriptionId, opts);
            // The lifecycle service writes the authoritative dates back onto the org row,
            // so re-read rather than returning the pre-subscription snapshot.
            return organizationRepository.findById(saved.getId()).orElse(saved);
        }
        return saved;
    }

    /** Backwards-compatible overload for callers that do not supply subscription options. */
    public Organization createOrganization(String name, String slug, String domain, Long planId, Long orgSubscriptionId) {
        return createOrganization(name, slug, domain, planId, orgSubscriptionId, null);
    }

    /**
     * Idempotently provisions the platform ghost super-admin inside an organization, so
     * the platform owner can access every tenant.
     *
     * <p>Both statements are NATIVE, and that is essential rather than stylistic. The
     * previous implementation set {@code OrganizationContext} to the target org and then
     * used JPA — but Hibernate fixes the session's tenant identifier when the session
     * OPENS, and with {@code open-in-view: true} that has already happened, bound to the
     * super admin's "-1" sentinel. The consequences were that
     * {@code existsByOrganizationIdAndEmail} always returned false (its results were
     * filtered to tenant "-1") and {@code save} then threw "assigned tenant id differs
     * from current tenant id: 2!=-1" — which aborted organization creation entirely.
     *
     * <p>Native SQL bypasses the discriminator, which is the same approach
     * {@code OrganizationController} already documents for cross-tenant admin work.
     */
    public void ensureGhostAdmin(Long orgId) {
        // Organization is not a BaseEntity, so no @TenantId filter applies here.
        if (!organizationRepository.existsById(orgId)) {
            return;
        }
        String ghostEmail = "admin@axisora.com";
        if (userRepository.existsAdminEmailInOrg(orgId, ghostEmail)) {
            return;
        }
        userRepository.insertGhostAdmin(orgId, ghostEmail,
                passwordEncoder.encode("admin123"), "Platform Admin");
    }

    /**
     * Updates an organization, treating null as "leave unchanged".
     *
     * <p>Previously every setter was called unconditionally, so a PUT that omitted a
     * field wiped it — a partial update sent from the Account page could blank an
     * organization's name or domain without ever mentioning them. {@code isActive} was
     * worse: because the request body was a {@code Map<String,String>}, an absent key
     * defaulted to {@code true} and silently reactivated a suspended tenant.
     */
    public Organization updateOrganization(Long id, String name, String slug, String domain,
                                            Boolean isActive, Long planId, Long orgSubscriptionId,
                                           String status, LocalDateTime purchaseDate, LocalDateTime expiryDate) {
        return updateOrganization(id, name, slug, domain, isActive, planId, orgSubscriptionId,
                status, purchaseDate, expiryDate, null);
    }

    /**
     * Updates an organization and, when the assigned plan changes, actually starts a
     * subscription term for it.
     *
     * <p>That last part is essential and was missing. Setting {@code org_subscription_id}
     * only points the row at a catalog entry; enforcement and the Account page both read
     * the tenant's {@code org_subscription_instances} record, which is what holds the
     * frozen price, limits and entitlements. Without one, an organization with a plan
     * selected in the edit form still resolved to no entitlements at all and reported
     * "No subscription assigned" to its own admin.
     *
     * <p>Uses {@code subscribe} rather than {@code changePlan} because this is an
     * administrative assignment by the platform owner, not a customer-initiated plan
     * change: it should not be prorated, and it should not be refused by the
     * downgrade-fits check when someone is correcting a mistake. The customer-facing
     * path with proration and guards is
     * {@code POST /api/platform/subscriptions/{id}/change-plan}.
     */
    public Organization updateOrganization(Long id, String name, String slug, String domain,
                                           Boolean isActive, Long planId, Long orgSubscriptionId,
                                           String status, LocalDateTime purchaseDate, LocalDateTime expiryDate,
                                           SubscriptionLifecycleService.SubscribeOptions subscribeOptions) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", id));

        Long previousPlanId = org.getOrgSubscriptionId();

        if (name != null && !name.isBlank()) org.setName(name);
        if (slug != null && !slug.isBlank()) org.setSlug(slug);
        if (domain != null) org.setDomain(domain);
        if (isActive != null) org.setIsActive(isActive);
        if (planId != null) org.setPlanId(planId);
        if (orgSubscriptionId != null) org.setOrgSubscriptionId(orgSubscriptionId);
        if (status != null && !status.isBlank()) org.setStatus(status);
        if (purchaseDate != null) org.setPurchaseDate(purchaseDate);
        if (expiryDate != null) org.setExpiryDate(expiryDate);
        organizationRepository.save(org);

        // Start a term when the plan was just assigned or changed, or when the column
        // points at a plan that has no instance behind it (the state left by assigning a
        // plan before this was wired up).
        if (orgSubscriptionId != null) {
            boolean planChanged = !orgSubscriptionId.equals(previousPlanId);
            boolean missingInstance = lifecycleService.findCurrent(id).isEmpty();

            if (planChanged || missingInstance) {
                SubscriptionLifecycleService.SubscribeOptions options = subscribeOptions != null
                        ? subscribeOptions : new SubscriptionLifecycleService.SubscribeOptions();
                if (options.changeReason == null
                        || options.changeReason == SubscriptionChangeReason.NEW) {
                    options.changeReason = missingInstance && !planChanged
                            ? SubscriptionChangeReason.NEW
                            : SubscriptionChangeReason.ADMIN_ADJUSTMENT;
                }
                if (options.changeNote == null) {
                    options.changeNote = "Plan assigned from the organization editor.";
                }
                lifecycleService.subscribe(id, orgSubscriptionId, options);
                return organizationRepository.findById(id).orElse(org);
            }
        }
        return org;
    }

    /** Sets the org's category (SCHOOL/COLLEGE/ACADEMY/TRAINING_INSTITUTE/OTHER). Null/blank leaves it unchanged. */
    public Organization updateCategory(Long id, String category) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", id));
        if (category != null && !category.isBlank()) {
            try {
                org.setCategory(com.institute.lms.entity.OrgCategory.valueOf(category.trim().toUpperCase()));
                organizationRepository.save(org);
            } catch (IllegalArgumentException ignored) {
                // Unknown category value: leave the existing category untouched rather than fail the request.
            }
        }
        return org;
    }

    /** Which payment gateway {@code StudentPaymentService} uses to collect this org's fees. */
    public Organization updateActiveGateway(Long id, String gateway) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", id));
        if (gateway != null && !gateway.isBlank()) {
            try {
                org.setActiveGateway(com.institute.lms.entity.PaymentGateway.valueOf(gateway.trim().toUpperCase()));
                organizationRepository.save(org);
            } catch (IllegalArgumentException ignored) {
                // Unknown gateway value: leave the existing gateway untouched rather than fail the request.
            }
        }
        return org;
    }

    /** Updates the billing identity and contact details shown on the Account page. */
    public Organization updateBillingDetails(Long id, Map<String, String> fields) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", id));

        applyIfPresent(fields, "legalName", org::setLegalName);
        applyIfPresent(fields, "gstin", org::setGstin);
        applyIfPresent(fields, "pan", org::setPan);
        applyIfPresent(fields, "billingEmail", org::setBillingEmail);
        applyIfPresent(fields, "billingPhone", org::setBillingPhone);
        applyIfPresent(fields, "billingAddress", org::setBillingAddress);
        applyIfPresent(fields, "city", org::setCity);
        applyIfPresent(fields, "stateCode", org::setStateCode);
        applyIfPresent(fields, "placeOfSupply", org::setPlaceOfSupply);
        applyIfPresent(fields, "pincode", org::setPincode);
        applyIfPresent(fields, "country", org::setCountry);
        applyIfPresent(fields, "contactPerson", org::setContactPerson);
        applyIfPresent(fields, "poNumber", org::setPoNumber);
        applyIfPresent(fields, "salesOwner", org::setSalesOwner);
        applyIfPresent(fields, "notes", org::setNotes);

        return organizationRepository.save(org);
    }

    /** Sets a field only when the key is actually present, preserving partial-update semantics. */
    private void applyIfPresent(Map<String, String> fields, String key, java.util.function.Consumer<String> setter) {
        if (fields != null && fields.containsKey(key)) {
            setter.accept(fields.get(key));
        }
    }

    /**
     * Renews an organization's subscription: reactivates it, resets the purchase date
     * to now, extends the expiry from today based on the assigned plan's period, and
     * increments the renewal counter (used to track renewed orgs on the dashboard).
     */
    public Organization renewOrganization(Long id) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", id));

        org.setStatus("ACTIVE");
        org.setIsActive(true);
        org.setRenewalCount((org.getRenewalCount() == null ? 0 : org.getRenewalCount()) + 1);
        organizationRepository.save(org);

        // Delegate the actual term to the lifecycle service so the renewal produces a
        // real subscription instance with its own frozen snapshot and audit event,
        // rather than just moving a date on the organization row. It writes the
        // authoritative purchase/expiry dates back here.
        if (org.getOrgSubscriptionId() != null) {
            if (lifecycleService.findCurrent(id).isPresent()) {
                lifecycleService.renew(id, "platform-admin");
            } else {
                lifecycleService.subscribe(id, org.getOrgSubscriptionId(),
                        new SubscriptionLifecycleService.SubscribeOptions());
            }
            return organizationRepository.findById(id).orElse(org);
        }

        // No plan assigned: fall back to the legacy date arithmetic so the action still
        // does something sensible for organizations created before plans existed.
        org.setPurchaseDate(LocalDateTime.now());
        org.setExpiryDate(computeExpiry(LocalDateTime.now(), null));
        return organizationRepository.save(org);
    }

    /** Computes the expiry date for a plan starting at {@code start}, from the plan period. */
    private LocalDateTime computeExpiry(LocalDateTime start, Long orgSubscriptionId) {
        if (orgSubscriptionId == null) {
            return start.plusYears(1);
        }
        OrgSubscription sub = orgSubscriptionRepository.findById(orgSubscriptionId).orElse(null);
        if (sub != null && "yearly".equalsIgnoreCase(sub.getPeriod())) {
            return start.plusYears(1);
        }
        if (sub != null && "weekly".equalsIgnoreCase(sub.getPeriod())) {
            return start.plusWeeks(1);
        }
        return start.plusMonths(1);
    }

    /** Uploads a logo file and stores the path on the Organization. */
    public String uploadLogo(Long orgId, MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Logo file is required");
        }

        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            throw new IllegalArgumentException("Only image files are allowed for logo upload");
        }

        Organization org = organizationRepository.findById(orgId).orElseThrow(() ->
                new RuntimeException("Organization not found"));

        String originalName = file.getOriginalFilename();
        String extension = originalName != null && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : ".png";
        String fileName = "logo-" + orgId + "-" + UUID.randomUUID().toString().substring(0, 8) + extension;

        String url;
        if (s3StorageService.isConfigured()) {
            String s3Key = s3StorageService.buildKey(orgId, "images", fileName);
            s3StorageService.upload(s3Key, file.getBytes(), contentType);
            url = "/api/media/serve-key?key=" + s3Key;
        } else {
            String uploadDir = "uploads/organization-logos";
            Path uploadPath = Paths.get(uploadDir);
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }
            Path filePath = uploadPath.resolve(fileName);
            Files.copy(file.getInputStream(), filePath);
            url = "/uploads/organization-logos/" + fileName;
        }

        org.setLogoUrl(url);
        organizationRepository.save(org);

        return url;
    }

    /**
     * Updates a single setting key on an organization.
     *
     * <p>Uses Jackson via {@link JsonUtils}. The previous implementation built the JSON
     * by string concatenation and regular expressions, which corrupted the whole
     * settings blob whenever a value contained a comma or a closing brace — a brand
     * colour list or an address was enough to do it. Jackson has been on the classpath
     * the whole time via {@code spring-boot-starter-web}.
     */
    public void updateOrgSetting(Long orgId, String key, String value) {
        Organization org = organizationRepository.findById(orgId).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", orgId));
        org.setSettings(JsonUtils.putKey(org.getSettings(), key, value));
        organizationRepository.save(org);
    }

    /** Merges several settings keys at once. A null value removes the key. */
    public void updateOrgSettings(Long orgId, Map<String, Object> updates) {
        Organization org = organizationRepository.findById(orgId).orElseThrow(() ->
                ResourceNotFoundException.of("Organization", orgId));
        org.setSettings(JsonUtils.mergeKeys(org.getSettings(), updates));
        organizationRepository.save(org);
    }

    public void deleteOrganization(Long id) {
        organizationRepository.deleteById(id);
    }
}
