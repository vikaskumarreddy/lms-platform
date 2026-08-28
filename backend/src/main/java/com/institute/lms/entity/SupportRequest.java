package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * A student asking placements staff about a drive (or an off-list company via
 * "Other"), raised from the mobile app and answered by an org admin on the
 * Placements page's Support tab.
 *
 * <p>organizationId is inherited from {@link BaseEntity} (@TenantId, stamped on insert).
 */
@Entity
@Table(name = "support_requests")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class SupportRequest extends BaseEntity {

    @Column(name = "student_id", nullable = false)
    private Long studentId;

    /** Null when the student picked "Other" instead of an existing drive. */
    @Column(name = "drive_id")
    private Long driveId;

    @Column(name = "company_name", nullable = false)
    private String companyName;

    @Column(columnDefinition = "TEXT")
    private String message;

    @Column(name = "status", nullable = false)
    private String status = "PENDING";

    @Column(name = "admin_response", columnDefinition = "TEXT")
    private String adminResponse;

    @Column(name = "decided_at")
    private LocalDateTime decidedAt;

    public boolean isPending() {
        return "PENDING".equals(status);
    }
}
