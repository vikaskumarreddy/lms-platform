package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;

// organizationId is inherited from BaseEntity (@TenantId, stamped on insert). One row per org.
@Entity
@Table(name = "org_feature_settings")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrgFeatureSettings extends BaseEntity {

    // ---- Push-notification categories, on by default so existing orgs see no change ----
    @Column(name = "notify_placements")
    private Boolean notifyPlacements = true;

    @Column(name = "notify_exams")
    private Boolean notifyExams = true;

    @Column(name = "notify_assignments")
    private Boolean notifyAssignments = true;

    @Column(name = "notify_grading")
    private Boolean notifyGrading = true;

    @Column(name = "notify_classes")
    private Boolean notifyClasses = true;

    @Column(name = "notify_certificates")
    private Boolean notifyCertificates = true;

    // ---- Daily attendance absentee alerts, opt-in since it's brand new ----
    @Column(name = "attendance_notifications_enabled")
    private Boolean attendanceNotificationsEnabled = false;

    // ---- Parent-visibility toggles, forward-looking for a future parent portal ----
    @Column(name = "parent_attendance_visible")
    private Boolean parentAttendanceVisible = true;

    @Column(name = "parent_grading_visible")
    private Boolean parentGradingVisible = true;

    @Column(name = "parent_fee_payments_visible")
    private Boolean parentFeePaymentsVisible = true;
}
