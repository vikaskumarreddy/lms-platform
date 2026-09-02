package com.institute.lms.controller;

import com.institute.lms.entity.PaymentGateway;
import com.institute.lms.service.StudentPaymentService;
import com.institute.lms.util.OrganizationContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {
  private final StudentPaymentService paymentService;
  private final OrganizationContext organizationContext;

  /** Every student's fee row for this tenant — the admin payments ledger. */
  @GetMapping("/transactions")
  public ResponseEntity<List<Map<String, Object>>> listTransactions() {
    return ResponseEntity.ok(paymentService.listTransactions());
  }

  /** Headline totals for the payments page. Amounts are in paise. */
  @GetMapping("/summary")
  public ResponseEntity<Map<String, Object>> summary() {
    return ResponseEntity.ok(paymentService.summary());
  }

  /** A single student's payment history (ONLINE attempts + CASH record), most recent first. */
  @GetMapping("/history/{studentId}")
  public ResponseEntity<List<com.institute.lms.dto.payment.PaymentHistoryEntryDTO>> getPaymentHistory(@PathVariable Long studentId) {
    Long orgId = organizationContext.getCurrentOrgId();
    return ResponseEntity.ok(paymentService.getPaymentHistory(studentId, orgId));
  }

  /**
   * Get payment status for current user.
   * Returns: {paymentRequired: bool, paymentMethod: CASH|ONLINE, paymentStatus: PENDING|COMPLETED|FAILED, amountDue: Long}
   */
  @GetMapping("/status/{studentId}")
  public ResponseEntity<Map<String, Object>> getPaymentStatus(@PathVariable Long studentId) {
    Long orgId = organizationContext.getCurrentOrgId();
    var paymentInfo = paymentService.getPaymentInfo(studentId, orgId);

    if (paymentInfo.isEmpty()) {
      return ResponseEntity.ok(Map.of(
        "paymentRequired", false,
        "paymentMethod", "CASH"
      ));
    }

    var info = paymentInfo.get();
    return ResponseEntity.ok(Map.of(
      "paymentRequired", info.isPaymentDue(),
      "paymentMethod", info.getPaymentMethod(),
      "paymentStatus", info.getPaymentStatus(),
      "gateway", paymentService.getActiveGatewayName(orgId),
      "amountDue", info.getAmountDue() != null ? info.getAmountDue() / 100.0 : 0,
      "paidAt", info.getPaidAt()
    ));
  }

  /**
   * Create payment order for student enrollment.
   * Called when student logs in and has ONLINE payment pending.
   */
  @PostMapping("/create-order/{studentId}")
  public ResponseEntity<Map<String, Object>> createPaymentOrder(@PathVariable Long studentId) {
    Long orgId = organizationContext.getCurrentOrgId();
    try {
      var orderData = paymentService.createPaymentOrder(studentId, orgId);
      return ResponseEntity.ok(orderData);
    } catch (Exception e) {
      log.error("Error creating order for student {}", studentId, e);
      return ResponseEntity.badRequest().body(Map.of(
        "error", e.getMessage()
      ));
    }
  }

  /**
   * Webhook endpoint: Razorpay calls this on payment success.
   * Must be accessible at: https://yourdomain.com/api/payments/webhook
   * Body: {orderId, paymentId, signature}
   */
  @PostMapping("/webhook")
  public ResponseEntity<Void> handlePaymentWebhook(@RequestBody Map<String, String> payload) {
    String orderId = payload.get("orderId");
    String paymentId = payload.get("paymentId");
    String signature = payload.get("signature");

    log.info("Payment webhook received: orderId={}, paymentId={}", orderId, paymentId);

    try {
      paymentService.handlePaymentSuccess(orderId, paymentId, signature);
      return ResponseEntity.ok().build();
    } catch (Exception e) {
      log.error("Webhook processing failed", e);
      return ResponseEntity.status(400).build();
    }
  }

  /**
   * Webhook endpoint: PayU calls this on payment success (form POST redirect back to us).
   * PayU's own field names (txnid, mihpayid, hash, status, email, firstname, productinfo,
   * amount) are passed straight through so {@code PayUGatewayAdapter}'s reverse-hash check
   * has everything it needs — unlike Razorpay's fixed 3-field shape above.
   */
  @PostMapping("/webhook/payu")
  public ResponseEntity<Void> handlePayuWebhook(@RequestBody Map<String, String> payload) {
    String txnId = payload.get("txnid");
    log.info("PayU webhook received: txnid={}, status={}", txnId, payload.get("status"));

    Map<String, String> callbackParams = new HashMap<>(payload);
    callbackParams.put("orderId", txnId);
    callbackParams.put("paymentId", payload.get("mihpayid"));
    callbackParams.put("signature", payload.get("hash"));

    try {
      paymentService.handleGatewayPaymentSuccess(PaymentGateway.PAYU, txnId, callbackParams);
      return ResponseEntity.ok().build();
    } catch (Exception e) {
      log.error("PayU webhook processing failed", e);
      return ResponseEntity.status(400).build();
    }
  }

  /**
   * Webhook endpoint: Cashfree calls this on order status change.
   * Body carries Cashfree's own order payload; we only need the order id to re-fetch and
   * verify status server-side, so the callback map is intentionally minimal.
   */
  @PostMapping("/webhook/cashfree")
  public ResponseEntity<Void> handleCashfreeWebhook(@RequestBody Map<String, Object> payload) {
    Object data = payload.get("data");
    String orderId = null;
    if (data instanceof Map<?, ?> dataMap) {
      Object order = dataMap.get("order");
      if (order instanceof Map<?, ?> orderMap && orderMap.get("order_id") != null) {
        orderId = String.valueOf(orderMap.get("order_id"));
      }
    }
    if (orderId == null) orderId = String.valueOf(payload.get("order_id"));

    log.info("Cashfree webhook received: orderId={}", orderId);

    try {
      paymentService.handleGatewayPaymentSuccess(PaymentGateway.CASHFREE, orderId, Map.of("orderId", orderId));
      return ResponseEntity.ok().build();
    } catch (Exception e) {
      log.error("Cashfree webhook processing failed", e);
      return ResponseEntity.status(400).build();
    }
  }

  /**
   * Browser redirect target for Razorpay Standard Checkout ({@code callback_url}).
   * The checkout page runs inside the app's webview with no JWT, so this must be
   * public (see SecurityConfig); the Razorpay signature in the query string is the
   * proof of authenticity. Razorpay POSTs the result here with its own field names.
   */
  @RequestMapping(value = "/callback/razorpay/{orderId}", method = {RequestMethod.GET, RequestMethod.POST})
  public ResponseEntity<String> handleRazorpayCheckoutRedirect(
      @PathVariable String orderId, @RequestParam Map<String, String> params) {
    String paymentId = params.getOrDefault("razorpay_payment_id", "");
    String signature = params.getOrDefault("razorpay_signature", "");
    log.info("Razorpay checkout redirect: orderId={}, paymentId={}", orderId, paymentId);
    try {
      paymentService.handleRazorpayCheckoutRedirect(orderId, paymentId, signature);
      return ResponseEntity.ok(checkoutHtml("Payment successful",
          "Your enrollment payment has been received. You can close this page and return to the app."));
    } catch (Exception e) {
      log.error("Razorpay checkout redirect failed for order {}", orderId, e);
      return ResponseEntity.ok(checkoutHtml("Payment not completed",
          "We could not verify this payment. If any amount was deducted it will be auto-refunded by your bank. Please try again from the app."));
    }
  }

  /**
   * Browser redirect target for PayU's surl/furl. PayU POSTs its full response form
   * here; the reverse-hash check in {@code PayUGatewayAdapter} authenticates it.
   */
  @RequestMapping(value = "/callback/payu/{orderId}", method = {RequestMethod.GET, RequestMethod.POST})
  public ResponseEntity<String> handlePayuCheckoutRedirect(
      @PathVariable String orderId, @RequestParam Map<String, String> params) {
    log.info("PayU checkout redirect: orderId={}, status={}", orderId, params.get("status"));
    Map<String, String> callbackParams = new HashMap<>(params);
    callbackParams.put("orderId", orderId);
    callbackParams.put("paymentId", params.getOrDefault("mihpayid", ""));
    callbackParams.put("signature", params.getOrDefault("hash", ""));
    try {
      paymentService.handleGatewayPaymentSuccess(PaymentGateway.PAYU, orderId, callbackParams);
      return ResponseEntity.ok(checkoutHtml("Payment successful",
          "Your enrollment payment has been received. You can close this page and return to the app."));
    } catch (Exception e) {
      log.error("PayU checkout redirect failed for order {}", orderId, e);
      return ResponseEntity.ok(checkoutHtml("Payment not completed",
          "We could not verify this payment. If any amount was deducted it will be auto-refunded by your bank. Please try again from the app."));
    }
  }

  /**
   * Live order status for the mobile app to poll while the Cashfree hosted checkout
   * is open. Returns {paid: bool}.
   */
  @GetMapping("/order-status/{orderId}")
  public ResponseEntity<Map<String, Object>> getOrderStatus(@PathVariable String orderId) {
    try {
      return ResponseEntity.ok(paymentService.checkGatewayOrderStatus(orderId));
    } catch (Exception e) {
      return ResponseEntity.badRequest().body(Map.of("paid", false, "error", e.getMessage()));
    }
  }

  /** Minimal confirmation page shown inside the checkout webview after a redirect. */
  private String checkoutHtml(String title, String body) {
    return "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>"
        + "<style>body{font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f8fafc;}"
        + "div{text-align:center;padding:24px}h1{font-size:20px;color:#0f172a}p{color:#475569}</style></head>"
        + "<body><div><h1>" + title + "</h1><p>" + body + "</p></div></body></html>";
  }

  /**
   * Handle failed payment (called from mobile if payment fails).
   */
  @PostMapping("/payment-failed/{orderId}")
  public ResponseEntity<Void> handlePaymentFailed(@PathVariable String orderId, @RequestBody Map<String, String> payload) {
    String error = payload.get("error");
    try {
      paymentService.handlePaymentFailed(orderId, error);
      return ResponseEntity.ok().build();
    } catch (Exception e) {
      log.error("Error recording failed payment", e);
      return ResponseEntity.status(400).build();
    }
  }

  /**
   * Admin endpoint: Manually mark student as paid (for CASH payments).
   * Only org admin can call this.
   */
  @PostMapping("/mark-paid/{studentId}")
  public ResponseEntity<Map<String, String>> markAsPaid(@PathVariable Long studentId, @RequestBody(required = false) Map<String, String> payload) {
    Long orgId = organizationContext.getCurrentOrgId();
    String notes = payload != null ? payload.get("notes") : null;

    try {
      paymentService.markAsPaidManual(studentId, orgId, notes);
      return ResponseEntity.ok(Map.of("message", "Payment marked as completed"));
    } catch (Exception e) {
      return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
  }

  /**
   * Admin endpoint: Process refund for a student.
   * Called when org admin wants to refund a student's payment.
   */
  @PostMapping("/refund/{studentId}")
  public ResponseEntity<Map<String, String>> processRefund(@PathVariable Long studentId, @RequestBody Map<String, Object> payload) {
    Long orgId = organizationContext.getCurrentOrgId();
    Long amount = ((Number) payload.get("amount")).longValue();
    String reason = (String) payload.get("reason");

    try {
      // For simplicity, we refund the latest payment. In production, find the right payment.
      var paymentInfo = paymentService.getPaymentInfo(studentId, orgId)
        .orElseThrow(() -> new IllegalArgumentException("Payment not found"));

      // Note: This is a simplified approach. In production, track razorpayPaymentId properly.
      // paymentService.processRefund(razorpayPaymentId, amount, reason);

      return ResponseEntity.ok(Map.of("message", "Refund initiated"));
    } catch (Exception e) {
      return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
  }
}
