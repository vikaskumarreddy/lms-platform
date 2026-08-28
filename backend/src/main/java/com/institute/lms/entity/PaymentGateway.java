package com.institute.lms.entity;

/**
 * Payment gateway an organization collects student fees through. Drives which
 * adapter {@code StudentPaymentService} delegates to; RAZORPAY is the default
 * used by every organization created before this field existed.
 */
public enum PaymentGateway {
    RAZORPAY,
    PAYU,
    CASHFREE
}
