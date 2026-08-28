package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;

// organizationId is inherited from BaseEntity (@TenantId, stamped on insert).
@Entity
@Table(name = "payment_refunds")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentRefund extends BaseEntity {
  @Column(name = "student_id")
  private Long studentId;

  @Column(name = "razorpay_refund_id", unique = true)
  private String razorpayRefundId;

  @Column(name = "razorpay_payment_id")
  private String razorpayPaymentId;

  @Column(name = "amount", nullable = false)
  private Long amount; // in paise

  @Column(name = "reason")
  private String reason;

  @Column(name = "status")
  private String status; // PENDING, PROCESSED, FAILED
}
