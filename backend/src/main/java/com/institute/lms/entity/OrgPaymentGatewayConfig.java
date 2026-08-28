package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;

/**
 * Per-organization, per-gateway credentials for a non-Razorpay payment vendor
 * (PayU, Cashfree). Razorpay keeps its own dedicated {@link OrgRazorpayConfig}
 * table untouched; this one is purely additive for the vendors introduced
 * alongside it, mirroring {@link OrgMessagingConfig}'s masked-JSON-credentials
 * shape since each vendor has its own distinct credential field set.
 */
@Entity
@Table(name = "org_payment_gateway_config")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrgPaymentGatewayConfig extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(name = "gateway", nullable = false, length = 30)
    private PaymentGateway gateway;

    /** JSON blob of vendor-specific credentials, e.g. PayU {key, salt, merchantId} or Cashfree {appId, secretKey}. */
    @Column(name = "credentials_json", columnDefinition = "TEXT")
    private String credentialsJson;

    @Column(name = "amount_per_student")
    private Long amountPerStudent;

    @Column(name = "payment_enabled")
    private Boolean paymentEnabled = false;
}
