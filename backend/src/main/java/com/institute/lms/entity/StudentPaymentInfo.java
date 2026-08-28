package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

// organizationId is inherited from BaseEntity, where it carries @TenantId and is
// stamped on insert. Redeclaring it here would shadow the field Hibernate actually
// filters on, so the tenant predicate and the stored value could drift apart.
@Entity
@Table(name = "student_payment_info", uniqueConstraints = {
  @UniqueConstraint(columnNames = {"student_id", "organization_id"})
})
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudentPaymentInfo extends BaseEntity {
  @Column(name = "student_id", nullable = false)
  private Long studentId;

  @Column(name = "payment_method", nullable = false)
  private String paymentMethod; // CASH, ONLINE

  @Column(name = "payment_status", nullable = false)
  private String paymentStatus; // PENDING, COMPLETED, FAILED

  @Column(name = "amount_due")
  private Long amountDue; // in paise

  @Column(name = "paid_at")
  private LocalDateTime paidAt;

  @Column(name = "notes")
  private String notes;

  public boolean isPaid() {
    return "COMPLETED".equals(paymentStatus);
  }

  public boolean isPaymentDue() {
    return "ONLINE".equals(paymentMethod) && !isPaid();
  }
}
