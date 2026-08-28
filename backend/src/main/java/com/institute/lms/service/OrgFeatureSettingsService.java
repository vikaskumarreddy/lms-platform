package com.institute.lms.service;

import com.institute.lms.entity.OrgFeatureSettings;
import com.institute.lms.repository.OrgFeatureSettingsRepository;
import org.springframework.stereotype.Service;

/**
 * Org-level on/off switches: which push-notification categories fire, whether
 * daily-attendance absentee alerts are enabled, and what a future parent portal
 * would be allowed to show. One row per org; a missing row just means every
 * toggle is at its default (see {@link OrgFeatureSettings} field defaults).
 */
@Service
public class OrgFeatureSettingsService {

    private final OrgFeatureSettingsRepository repository;

    public OrgFeatureSettingsService(OrgFeatureSettingsRepository repository) {
        this.repository = repository;
    }

    /** Never returns null: an org with no saved row simply gets all-defaults settings. */
    public OrgFeatureSettings getEffective(Long organizationId) {
        return repository.findByOrganizationId(organizationId).orElseGet(OrgFeatureSettings::new);
    }

    public OrgFeatureSettings getOrCreate(Long organizationId) {
        return repository.findByOrganizationId(organizationId).orElseGet(() -> {
            OrgFeatureSettings settings = new OrgFeatureSettings();
            settings.setOrganizationId(organizationId);
            return repository.save(settings);
        });
    }

    public OrgFeatureSettings save(Long organizationId, OrgFeatureSettings updates) {
        OrgFeatureSettings settings = getOrCreate(organizationId);
        if (updates.getNotifyPlacements() != null) settings.setNotifyPlacements(updates.getNotifyPlacements());
        if (updates.getNotifyExams() != null) settings.setNotifyExams(updates.getNotifyExams());
        if (updates.getNotifyAssignments() != null) settings.setNotifyAssignments(updates.getNotifyAssignments());
        if (updates.getNotifyGrading() != null) settings.setNotifyGrading(updates.getNotifyGrading());
        if (updates.getNotifyClasses() != null) settings.setNotifyClasses(updates.getNotifyClasses());
        if (updates.getNotifyCertificates() != null) settings.setNotifyCertificates(updates.getNotifyCertificates());
        if (updates.getAttendanceNotificationsEnabled() != null) {
            settings.setAttendanceNotificationsEnabled(updates.getAttendanceNotificationsEnabled());
        }
        if (updates.getParentAttendanceVisible() != null) settings.setParentAttendanceVisible(updates.getParentAttendanceVisible());
        if (updates.getParentGradingVisible() != null) settings.setParentGradingVisible(updates.getParentGradingVisible());
        if (updates.getParentFeePaymentsVisible() != null) settings.setParentFeePaymentsVisible(updates.getParentFeePaymentsVisible());
        return repository.save(settings);
    }
}
