package com.institute.lms.controller;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.entity.User;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.OrgSubscriptionRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Platform-level (super admin) analytics for the SaaS management portal,
 * shown on the main portal (localhost:4200).
 */
@RestController
@RequestMapping("/api/saas")
public class SaasStatsController {

    private final OrganizationRepository organizationRepository;
    private final OrgSubscriptionRepository orgSubscriptionRepository;
    private final UserRepository userRepository;
    private final UserContext userContext;

    public SaasStatsController(OrganizationRepository organizationRepository,
                               OrgSubscriptionRepository orgSubscriptionRepository,
                               UserRepository userRepository,
                               UserContext userContext) {
        this.organizationRepository = organizationRepository;
        this.orgSubscriptionRepository = orgSubscriptionRepository;
        this.userRepository = userRepository;
        this.userContext = userContext;
    }

    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> stats() {
        if (!userContext.isAdmin()) {
            throw new RuntimeException("Access denied: Admin role required");
        }

        List<Organization> orgs = organizationRepository.findAll();

        long totalOrgs = orgs.size();
        long activeOrgs = orgs.stream().filter(o -> Boolean.TRUE.equals(o.getIsActive()) && !isExpired(o)).count();
        long expiredOrgs = orgs.stream().filter(this::isExpired).count();
        long totalOrgAdmins = userRepository.countByRole(User.UserRole.INSTITUTE_ADMIN);
        long totalTeachers = userRepository.countByRole(User.UserRole.INSTRUCTOR);
        long totalStudents = userRepository.countByRole(User.UserRole.STUDENT);
        long totalUsers = userRepository.count();
        long totalSubscriptions = orgSubscriptionRepository.count();

        // MRR estimate: sum of assigned org-subscription prices across active orgs.
        BigDecimal mrr = computeMonthlyRecurringRevenue(orgs);
        // Renewal tracking: total renewals performed + percentage of orgs renewed.
        long renewalCount = orgs.stream().mapToLong(o -> o.getRenewalCount() == null ? 0L : o.getRenewalCount()).sum();
        double renewalPercentage = totalOrgs == 0 ? 0.0
                : Math.round((renewalCount * 100.0 / totalOrgs) * 100.0) / 100.0;
        List<Map<String, Object>> orgsBySubscription = new ArrayList<>();
        Map<Long, Long> subUsage = new LinkedHashMap<>();
        for (Organization o : orgs) {
            if (Boolean.TRUE.equals(o.getIsActive()) && o.getOrgSubscriptionId() != null) {
                subUsage.merge(o.getOrgSubscriptionId(), 1L, Long::sum);
            }
        }
        for (Map.Entry<Long, Long> e : subUsage.entrySet()) {
            orgSubscriptionRepository.findById(e.getKey()).ifPresent(sub -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("id", sub.getId());
                m.put("name", sub.getName());
                m.put("usageCount", e.getValue());
                orgsBySubscription.add(m);
            });
        }
        orgsBySubscription.sort(Comparator.comparingLong((Map<String, Object> m) -> (Long) m.get("usageCount")).reversed());

        List<Map<String, Object>> recentOrgs = orgs.stream()
                .sorted(Comparator.comparing(Organization::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(6)
                .map(o -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", o.getId());
                    m.put("name", o.getName());
                    m.put("slug", o.getSlug());
                    m.put("isActive", o.getIsActive());
                    m.put("orgSubscriptionName", resolveSubName(o.getOrgSubscriptionId()));
                    m.put("createdAt", o.getCreatedAt());
                    return m;
                })
                .toList();

        // All available plans (for the subscriptions overview).
        List<Map<String, Object>> plans = orgSubscriptionRepository.findAll().stream()
                .map(this::toPlanMap)
                .toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("totalOrganizations", totalOrgs);
        result.put("activeOrganizations", activeOrgs);
        result.put("expiredOrganizations", expiredOrgs);
        result.put("totalRevenue", mrr);
        result.put("renewalCount", renewalCount);
        result.put("renewalPercentage", renewalPercentage);
        result.put("totalOrgAdmins", totalOrgAdmins);
        result.put("totalTeachers", totalTeachers);
        result.put("totalStudents", totalStudents);
        result.put("totalUsers", totalUsers);
        result.put("totalSubscriptions", totalSubscriptions);
        result.put("mrr", mrr);
        result.put("orgsBySubscription", orgsBySubscription);
        result.put("recentOrganizations", recentOrgs);
        result.put("subscriptions", plans);
        return ResponseEntity.ok(result);
    }

    private BigDecimal computeMonthlyRecurringRevenue(List<Organization> orgs) {
        BigDecimal total = BigDecimal.ZERO;
        for (Organization o : orgs) {
            if (Boolean.TRUE.equals(o.getIsActive()) && !isExpired(o) && o.getOrgSubscriptionId() != null) {
                OrgSubscription sub = orgSubscriptionRepository.findById(o.getOrgSubscriptionId()).orElse(null);
                if (sub != null && sub.getPrice() != null) {
                    total = total.add(sub.getPrice());
                }
            }
        }
        return total;
    }

    /** True when the organization's plan has passed its expiry date. */
    private boolean isExpired(Organization o) {
        return o.getExpiryDate() != null && o.getExpiryDate().isBefore(LocalDateTime.now());
    }

    private String resolveSubName(Long id) {
        if (id == null) return null;
        return orgSubscriptionRepository.findById(id).map(OrgSubscription::getName).orElse(null);
    }

    private Map<String, Object> toPlanMap(OrgSubscription s) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", s.getId());
        m.put("name", s.getName());
        m.put("description", s.getDescription());
        m.put("price", s.getPrice());
        m.put("period", s.getPeriod());
        m.put("isActive", s.getIsActive());
        m.put("isPopular", s.getIsPopular());
        return m;
    }
}