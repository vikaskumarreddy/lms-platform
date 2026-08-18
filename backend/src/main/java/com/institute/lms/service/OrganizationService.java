package com.institute.lms.service;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.User;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.OrgSubscriptionRepository;
import com.institute.lms.repository.UserRepository;
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

    public OrganizationService(OrganizationRepository organizationRepository,
                               OrganizationContext organizationContext,
                               UserRepository userRepository,
                               PasswordEncoder passwordEncoder,
                               OrgSubscriptionRepository orgSubscriptionRepository) {
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.orgSubscriptionRepository = orgSubscriptionRepository;
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

    /** Creates a new organization (tenant) and auto-provisions the platform
     *  ghost super-admin (admin@axisora.com / admin123) inside it so the platform
     *  owner can access every tenant. */
    public Organization createOrganization(String name, String slug, String domain, Long planId, Long orgSubscriptionId) {
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
        return saved;
    }

            /** Idempotently creates the ghost super-admin for an organization if absent. */
        public void ensureGhostAdmin(Long orgId) {
        // Fetch the Organization entity (NOT a BaseEntity, so no @TenantId filter applies).
        Organization org = organizationRepository.findById(orgId).orElse(null);
        if (org == null) {
            return;
        }
        // Temporarily set the tenant context so Hibernate's @TenantId DISCRIMINATOR
        // predicate matches the organizationId we are about to write on the User.
        // Without this, the super-admin request thread carries the "-1" sentinel
        // tenant, which causes existsByOrganizationIdAndEmail to always return
        // false and userRepository.save to throw PropertyValueException.
        organizationContext.setCurrentOrganization(org);
        try {
            String ghostEmail = "admin@axisora.com";
            if (userRepository.existsByOrganizationIdAndEmail(orgId, ghostEmail)) {
                return;
            }
            User ghost = new User();
            ghost.setEmail(ghostEmail);
            ghost.setPassword(passwordEncoder.encode("admin123"));
            ghost.setName("Platform Admin");
            ghost.setRole(User.UserRole.ADMIN);
            ghost.setIsActive(true);
            ghost.setIsEmailVerified(true);
            ghost.setIsGhost(true);
            ghost.setOrganizationId(orgId);
            userRepository.save(ghost);
        } finally {
            organizationContext.clear();
        }
    }

    /** Updates an existing organization's general settings. */
    public Organization updateOrganization(Long id, String name, String slug, String domain,
                                            Boolean isActive, Long planId, Long orgSubscriptionId,
                                           String status, LocalDateTime purchaseDate, LocalDateTime expiryDate) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                new RuntimeException("Organization not found"));
        org.setName(name);
        org.setSlug(slug);
        org.setDomain(domain);
        org.setIsActive(isActive);
        org.setPlanId(planId);
        org.setOrgSubscriptionId(orgSubscriptionId);
        if (status != null && !status.isBlank()) org.setStatus(status);
        if (purchaseDate != null) org.setPurchaseDate(purchaseDate);
        if (expiryDate != null) org.setExpiryDate(expiryDate);
        return organizationRepository.save(org);
    }

    /**
     * Renews an organization's subscription: reactivates it, resets the purchase date
     * to now, extends the expiry from today based on the assigned plan's period, and
     * increments the renewal counter (used to track renewed orgs on the dashboard).
     */
    public Organization renewOrganization(Long id) {
        Organization org = organizationRepository.findById(id).orElseThrow(() ->
                new RuntimeException("Organization not found"));
        org.setStatus("ACTIVE");
        org.setIsActive(true);
        org.setPurchaseDate(LocalDateTime.now());
        org.setExpiryDate(computeExpiry(LocalDateTime.now(), org.getOrgSubscriptionId()));
        org.setRenewalCount((org.getRenewalCount() == null ? 0 : org.getRenewalCount()) + 1);
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

        String uploadDir = "uploads/organization-logos";
        Path uploadPath = Paths.get(uploadDir);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        String originalName = file.getOriginalFilename();
        String extension = originalName != null && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : ".png";
        String fileName = "logo-" + orgId + "-" + UUID.randomUUID().toString().substring(0, 8) + extension;
        Path filePath = uploadPath.resolve(fileName);

        Files.copy(file.getInputStream(), filePath);

        String url = "/uploads/organization-logos/" + fileName;
        org.setLogoUrl(url);
        organizationRepository.save(org);

        return url;
    }

    /** Updates a specific setting key for an organization. */
    public void updateOrgSetting(Long orgId, String key, String value) {
        Organization org = organizationRepository.findById(orgId).orElseThrow(() ->
                new RuntimeException("Organization not found"));
        // Simple JSON merge using the settings JSON string
        String settings = org.getSettings() != null ? org.getSettings() : "{}";
        // For simplicity, replace the entire settings JSON with the given key/value
        // In a production app, use a proper JSON library (Jackson)
        if (settings.equals("{}") || settings.isEmpty()) {
            settings = "\"" + key + "\":\"" + value + "\"";
        } else {
            // Basic approach: find existing key or add new one
            String escapedValue = value.replace("\\", "\\\\").replace("\"", "\\\"");
            if (settings.contains("\"" + key + "\"")) {
                // Replace existing value using regex-like approach
                settings = settings.replaceAll(
                        "\"" + key + "\":.*?(?=,|\\})",
                        "\"" + key + "\":\"" + escapedValue + "\""
                );
            } else {
                settings = settings.replaceAll("\\}$", "") + ",\"" + key + "\":\"" + escapedValue + "\"}";
            }
        }
        org.setSettings("{" + settings + "}");
        organizationRepository.save(org);
    }

    public void deleteOrganization(Long id) {
        organizationRepository.deleteById(id);
    }
}
