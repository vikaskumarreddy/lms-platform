package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * A student asking to move to a different subscription plan.
 *
 * <p>Raised from the mobile app and settled by an org admin on the Subscriptions
 * page. Approving is what actually moves the student onto the new plan; until then
 * this row is only a request, so a student can never upgrade themselves.
 *
 * <p>organizationId is inherited from {@link BaseEntity} (@TenantId, stamped on insert).
 */
@Entity
@Table(name = "student_plan_requests")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class StudentPlanRequest extends BaseEntity {

    @Column(name = "student_id", nullable = false)
    private Long studentId;

    @Column(name = "requested_plan_id", nullable = false)
    private Long requestedPlanId;

    /** Snapshot of the plan they were on when they asked, for context at decision time. */
    @Column(name = "current_plan_id")
    private Long currentPlanId;

    @Column(name = "status", nullable = false)
    private String status = "PENDING";

    @Column(name = "student_note")
    private String studentNote;

    @Column(name = "decision_note")
    private String decisionNote;

    @Column(name = "decided_by")
    private String decidedBy;

    @Column(name = "decided_at")
    private LocalDateTime decidedAt;

    public boolean isPending() {
        return "PENDING".equals(status);
    }
}
