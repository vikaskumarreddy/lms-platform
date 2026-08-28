package com.institute.lms.service.payment;

import com.institute.lms.entity.OrgRazorpayConfig;
import com.institute.lms.entity.PaymentGateway;
import com.institute.lms.repository.OrgRazorpayConfigRepository;
import com.institute.lms.service.RazorpayService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Map;

/**
 * Thin adapter over the existing, untouched {@link RazorpayService} /
 * {@link OrgRazorpayConfig} so the multi-gateway abstraction can address
 * Razorpay uniformly. {@code StudentPaymentService}'s RAZORPAY branch calls
 * {@link RazorpayService} directly (unchanged, pre-existing code path) rather
 * than through this adapter - this class exists so Razorpay is a first-class,
 * swappable {@link PaymentGatewayService} for any future caller that wants
 * gateway-agnostic dispatch.
 */
@Component
@RequiredArgsConstructor
public class RazorpayGatewayAdapter implements PaymentGatewayService {
    private final RazorpayService razorpayService;
    private final OrgRazorpayConfigRepository configRepository;

    @Override
    public PaymentGateway getGateway() {
        return PaymentGateway.RAZORPAY;
    }

    @Override
    public Map<String, Object> createOrder(Long organizationId, Long amount, String currency,
                                            String receiptRef, Map<String, String> customer) {
        OrgRazorpayConfig config = configRepository.findByOrganizationId(organizationId)
                .orElseThrow(() -> new IllegalStateException("Razorpay not configured"));
        Map<String, Object> order = razorpayService.createOrder(
                config.getRazorpayKeyId(), config.getRazorpayKeySecret(), amount, currency, receiptRef);
        return Map.of(
                "orderId", order.get("id"),
                "amount", amount,
                "currency", currency,
                "keyId", config.getRazorpayKeyId()
        );
    }

    @Override
    public String verifyAndCapture(Long organizationId, Map<String, String> callbackParams) {
        OrgRazorpayConfig config = configRepository.findByOrganizationId(organizationId)
                .orElseThrow(() -> new IllegalStateException("Razorpay not configured"));
        String orderId = callbackParams.get("orderId");
        String paymentId = callbackParams.get("paymentId");
        String signature = callbackParams.get("signature");
        if (!razorpayService.verifySignature(orderId, paymentId, signature, config.getRazorpayWebhookSecret())) {
            throw new SecurityException("Invalid signature");
        }
        return paymentId;
    }

    @Override
    public String refund(Long organizationId, String paymentReference, Long amount) {
        OrgRazorpayConfig config = configRepository.findByOrganizationId(organizationId)
                .orElseThrow(() -> new IllegalStateException("Razorpay not configured"));
        return razorpayService.refundPayment(config.getRazorpayKeyId(), config.getRazorpayKeySecret(), paymentReference, amount);
    }
}
