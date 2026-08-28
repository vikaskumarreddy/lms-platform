package com.institute.lms.controller;

import com.institute.lms.entity.OrgFeatureSettings;
import com.institute.lms.service.OrgFeatureSettingsService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Org-level on/off switches for push-notification categories, daily-attendance
 * absentee alerts, and (forward-looking) parent-visibility flags. No secrets
 * here, so unlike {@link OrgRazorpayConfigController}/{@code OrgMessagingConfigController}
 * there is nothing to mask - this is a plain read/merge-write of booleans.
 */
@RestController
@RequestMapping("/api/org-feature-settings")
@RequiredArgsConstructor
public class OrgFeatureSettingsController {

    private final OrgFeatureSettingsService featureSettingsService;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    @GetMapping
    public ResponseEntity<OrgFeatureSettings> get() {
        Long orgId = organizationContext.getCurrentOrgId();
        return ResponseEntity.ok(featureSettingsService.getEffective(orgId));
    }

    @PutMapping
    public ResponseEntity<OrgFeatureSettings> save(@RequestBody OrgFeatureSettings updates) {
        userContext.requireOrgAdmin();
        Long orgId = organizationContext.getCurrentOrgId();
        return ResponseEntity.ok(featureSettingsService.save(orgId, updates));
    }
}
