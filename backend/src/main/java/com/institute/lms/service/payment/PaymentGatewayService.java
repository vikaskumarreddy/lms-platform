package com.institute.lms.service.payment;

import com.institute.lms.entity.PaymentGateway;

import java.util.Map;

/**
 * Uniform surface over a payment vendor's order/verify/refund calls, so
 * {@code StudentPaymentService} can address PayU/Cashfree the same way it
 * already addresses Razorpay directly. Implementations are looked up by
 * {@link #getGateway()} via {@link PaymentGatewayResolver}.
 */
public interface PaymentGatewayService {

    PaymentGateway getGateway();

    /**
     * Starts a new order for the given org/amount. Returns whatever fields the
     * checkout client (mobile app / admin browser) needs to complete payment -
     * shape differs per gateway, but always includes an "orderId" key.
     */
    Map<String, Object> createOrder(Long organizationId, Long amount, String currency,
                                     String receiptRef, Map<String, String> customer);

    /**
     * Confirms a payment given the gateway's own callback/webhook parameters
     * (caller normalizes into orderId/paymentId/signature-shaped keys). Returns
     * the gateway's payment reference id on success, throws otherwise.
     */
    String verifyAndCapture(Long organizationId, Map<String, String> callbackParams);

    /** Issues a refund, returning the gateway's refund reference id. */
    String refund(Long organizationId, String paymentReference, Long amount);
}
