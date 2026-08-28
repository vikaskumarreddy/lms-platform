package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

// organizationId is inherited from BaseEntity (@TenantId, stamped on insert).
@Entity
@Table(name = "org_razorpay_config")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrgRazorpayConfig extends BaseEntity {
  @Column(name = "razorpay_key_id", nullable = false)
  private String razorpayKeyId;

  @Column(name = "razorpay_key_secret", nullable = false)
  private String razorpayKeySecret;

  @Column(name = "razorpay_webhook_secret")
  private String razorpayWebhookSecret;

  @Column(name = "amount_per_student")
  private Long amountPerStudent; // in paise

  @Column(name = "payment_enabled")
  private Boolean paymentEnabled = false;
}
