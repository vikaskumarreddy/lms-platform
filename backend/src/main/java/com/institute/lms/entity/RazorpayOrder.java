package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;

// organizationId is inherited from BaseEntity (@TenantId, stamped on insert).
@Entity
@Table(name = "razorpay_orders")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RazorpayOrder extends BaseEntity {
  @Column(name = "student_id")
  private Long studentId;

  @Column(name = "razorpay_order_id", nullable = false, unique = true)
  private String razorpayOrderId;

  @Column(name = "razorpay_payment_id", unique = true)
  private String razorpayPaymentId;

  @Column(name = "razorpay_signature")
  private String razorpaySignature;

  @Column(name = "amount", nullable = false)
  private Long amount; // in paise

  @Column(name = "currency")
  private String currency = "INR";

  @Column(name = "status", nullable = false)
  private String status; // PENDING, AUTHORIZED, CAPTURED, FAILED

  @Column(name = "attempt_count")
  private Integer attemptCount = 1;

  @Column(name = "last_error")
  private String lastError;

  public boolean isPending() {
    return "PENDING".equals(status);
  }

  public boolean isAuthorized() {
    return "AUTHORIZED".equals(status) || "CAPTURED".equals(status);
  }
}
