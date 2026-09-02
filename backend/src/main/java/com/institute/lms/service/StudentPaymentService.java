package com.institute.lms.service;

import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import com.institute.lms.service.payment.PaymentGatewayResolver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Optional;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class StudentPaymentService {
  private final StudentPaymentInfoRepository studentPaymentInfoRepo;
  private final RazorpayOrderRepository razorpayOrderRepo;
  private final OrgRazorpayConfigRepository orgConfigRepo;
  private final PaymentRefundRepository refundRepo;
  private final RazorpayService razorpayService;
  private final UserRepository userRepository;
  private final OrganizationRepository organizationRepository;
  private final OrgPaymentGatewayConfigRepository gatewayConfigRepo;
  private final PaymentGatewayResolver gatewayResolver;
  private final SubscriptionPlanRepository subscriptionPlanRepo;

  /** Null on legacy rows means RAZORPAY, the gateway every org used before this field existed. */
  private PaymentGateway resolveActiveGateway(Long organizationId) {
    return organizationRepository.findById(organizationId)
      .map(Organization::getActiveGateway)
      .orElse(PaymentGateway.RAZORPAY);
  }

  @Transactional
  public void createPaymentForNewStudent(Long studentId, Long organizationId, String paymentMethod) {
    // Create payment info for new student
    StudentPaymentInfo paymentInfo = StudentPaymentInfo.builder()
      .studentId(studentId)
      .paymentMethod(paymentMethod)
      .paymentStatus("PENDING")
      .build();
    // Set explicitly rather than relying on the @PrePersist stamp: the caller may be
    // acting for a specific organization, and a mis-stamped fee row is a billing bug.
    paymentInfo.setOrganizationId(organizationId);

    // Resolve the amount from the student's subscription plan (different plans have
    // different prices), then record it on the payment row as paise.
    if ("ONLINE".equals(paymentMethod)) {
      paymentInfo.setAmountDue(resolveStudentAmountDue(studentId, organizationId));
    }

    studentPaymentInfoRepo.save(paymentInfo);
    log.info("Created payment info for student {} with method {} and amount {} paise",
        studentId, paymentMethod, paymentInfo.getAmountDue());
  }

  /** Amount in paise the student owes for enrollment: their {@link SubscriptionPlan}
   * price (rupees -> paise). Different subscriptions carry different prices, so the
   * legacy hard-coded "amount per student" in payment settings is never used — if the
   * student has no priced plan attached the amount stays 0 and the admin must fix the
   * plan before the student can pay. */
  private Long resolveStudentAmountDue(Long studentId, Long organizationId) {
    Optional<User> studentOpt = userRepository.findById(studentId);
    if (studentOpt.isPresent() && studentOpt.get().getPlanId() != null) {
      Optional<SubscriptionPlan> planOpt = subscriptionPlanRepo.findById(studentOpt.get().getPlanId());
      if (planOpt.isPresent() && planOpt.get().getPrice() != null) {
        return planOpt.get().getPrice().multiply(BigDecimal.valueOf(100)).longValue();
      }
      log.warn("Student {} has plan {} with no price set — amount due recorded as 0", studentId, studentOpt.get().getPlanId());
    } else {
      log.warn("Student {} has no subscription plan — amount due recorded as 0", studentId);
    }
    return 0L;
  }

  /**
   * Re-derive the amount due from the student's current subscription plan. Called when
   * an admin moves an unpaid ONLINE student to a different plan, so the next checkout
   * charges the new plan's price rather than the old one. No-op for paid or cash rows.
   */
  @Transactional
  public void refreshAmountDueFromPlan(Long studentId, Long organizationId) {
    studentPaymentInfoRepo.findByStudentIdAndOrganizationId(studentId, organizationId)
      .filter(info -> "ONLINE".equals(info.getPaymentMethod()) && !info.isPaid())
      .ifPresent(info -> {
        long newAmount = resolveStudentAmountDue(studentId, organizationId);
        if (info.getAmountDue() == null || info.getAmountDue() != newAmount) {
          info.setAmountDue(newAmount);
          studentPaymentInfoRepo.save(info);
          log.info("Amount due for student {} refreshed to {} paise after plan change", studentId, newAmount);
        }
      });
  }

  /** The active payment gateway name (RAZORPAY/PAYU/CASHFREE) for an organization,
   * so the mobile client knows which vendor's checkout to launch. */
  public String getActiveGatewayName(Long organizationId) {
    return resolveActiveGateway(organizationId).name();
  }

  public Optional<StudentPaymentInfo> getPaymentInfo(Long studentId, Long organizationId) {
    return studentPaymentInfoRepo.findByStudentIdAndOrganizationId(studentId, organizationId);
  }

  /** Public base URL of this backend, used to build gateway redirect targets. */
  @org.springframework.beans.factory.annotation.Value("${app.public-base-url:}")
  private String appBaseUrl;

  @Transactional
  public Map<String, Object> createPaymentOrder(Long studentId, Long organizationId) {
    PaymentGateway activeGateway = resolveActiveGateway(organizationId);
    if (activeGateway != PaymentGateway.RAZORPAY) {
      return createPaymentOrderViaGateway(activeGateway, studentId, organizationId);
    }

    StudentPaymentInfo paymentInfo = studentPaymentInfoRepo
      .findByStudentIdAndOrganizationId(studentId, organizationId)
      .orElseThrow(() -> new IllegalArgumentException("Payment info not found"));

    if (!paymentInfo.isPaymentDue()) {
      throw new IllegalStateException("Payment already completed or not required");
    }

    OrgRazorpayConfig config = orgConfigRepo.findByOrganizationId(organizationId)
      .orElseThrow(() -> new IllegalStateException("Razorpay not configured"));

    // Create order using org's Razorpay account
    Map<String, Object> orderData = razorpayService.createOrder(
      config.getRazorpayKeyId(),
      config.getRazorpayKeySecret(),
      paymentInfo.getAmountDue(),
      "INR",
      "Student enrollment - Org #" + organizationId
    );

    String razorpayOrderId = (String) orderData.get("id");

    // Save order record
    RazorpayOrder order = RazorpayOrder.builder()
      .studentId(studentId)
      .razorpayOrderId(razorpayOrderId)
      .amount(paymentInfo.getAmountDue())
      .currency("INR")
      .status("PENDING")
      .build();
    order.setOrganizationId(organizationId);
    razorpayOrderRepo.save(order);

    return Map.of(
      "orderId", razorpayOrderId,
      "amount", paymentInfo.getAmountDue(),
      "currency", "INR",
      "keyId", config.getRazorpayKeyId(),
      // Browser redirect target: the checkout page POSTs the payment result here
      // (public endpoint — the Razorpay signature authenticates it).
      "callbackUrl", appBaseUrl + "/api/payments/callback/razorpay/" + razorpayOrderId
    );
  }

  /** Non-Razorpay counterpart to the block above, dispatched via {@link PaymentGatewayResolver}. */
  private Map<String, Object> createPaymentOrderViaGateway(PaymentGateway gateway, Long studentId, Long organizationId) {
    StudentPaymentInfo paymentInfo = studentPaymentInfoRepo
      .findByStudentIdAndOrganizationId(studentId, organizationId)
      .orElseThrow(() -> new IllegalArgumentException("Payment info not found"));

    if (!paymentInfo.isPaymentDue()) {
      throw new IllegalStateException("Payment already completed or not required");
    }

    User student = userRepository.findById(studentId).orElse(null);
    Map<String, String> customer = new LinkedHashMap<>();
    if (student != null) {
      if (student.getName() != null) customer.put("name", student.getName());
      if (student.getEmail() != null) customer.put("email", student.getEmail());
      if (student.getPhone() != null) customer.put("phone", student.getPhone());
    }

    String receiptRef = "order_" + organizationId + "_" + studentId + "_" + System.currentTimeMillis();
    Map<String, Object> orderData = gatewayResolver.resolve(gateway)
      .createOrder(organizationId, paymentInfo.getAmountDue(), "INR", receiptRef, customer);

    String orderId = String.valueOf(orderData.get("orderId"));

    RazorpayOrder order = RazorpayOrder.builder()
      .studentId(studentId)
      .razorpayOrderId(orderId)
      .amount(paymentInfo.getAmountDue())
      .currency("INR")
      .status("PENDING")
      .build();
    order.setOrganizationId(organizationId);
    razorpayOrderRepo.save(order);

    return orderData;
  }

  @Transactional
  public void handlePaymentSuccess(String razorpayOrderId, String razorpayPaymentId, String signature) {
    RazorpayOrder order = razorpayOrderRepo.findByRazorpayOrderId(razorpayOrderId)
      .orElseThrow(() -> new IllegalArgumentException("Order not found: " + razorpayOrderId));

    OrgRazorpayConfig config = orgConfigRepo.findByOrganizationId(order.getOrganizationId())
      .orElseThrow(() -> new IllegalStateException("Config not found"));

    // Verify signature
    if (!razorpayService.verifySignature(razorpayOrderId, razorpayPaymentId, signature, config.getRazorpayWebhookSecret())) {
      log.warn("Signature verification failed for payment {}", razorpayPaymentId);
      throw new SecurityException("Invalid signature");
    }

    // Update order
    order.setRazorpayPaymentId(razorpayPaymentId);
    order.setRazorpaySignature(signature);
    order.setStatus("CAPTURED");
    razorpayOrderRepo.save(order);

    // Update payment info
    StudentPaymentInfo paymentInfo = studentPaymentInfoRepo
      .findByStudentIdAndOrganizationId(order.getStudentId(), order.getOrganizationId())
      .orElseThrow(() -> new IllegalArgumentException("Payment info not found"));

    paymentInfo.setPaymentStatus("COMPLETED");
    paymentInfo.setPaidAt(LocalDateTime.now());
    studentPaymentInfoRepo.save(paymentInfo);

    log.info("Payment completed for student {} from org {}", order.getStudentId(), order.getOrganizationId());
  }

  @Transactional
  public void handlePaymentFailed(String razorpayOrderId, String error) {
    RazorpayOrder order = razorpayOrderRepo.findByRazorpayOrderId(razorpayOrderId)
      .orElseThrow(() -> new IllegalArgumentException("Order not found"));

    order.setStatus("FAILED");
    order.setLastError(error);
    order.setAttemptCount(order.getAttemptCount() + 1);
    razorpayOrderRepo.save(order);

    log.warn("Payment failed for order {}: {}", razorpayOrderId, error);
  }

  @Transactional
  public void markAsPaidManual(Long studentId, Long organizationId, String notes) {
    StudentPaymentInfo paymentInfo = studentPaymentInfoRepo
      .findByStudentIdAndOrganizationId(studentId, organizationId)
      .orElseThrow(() -> new IllegalArgumentException("Payment info not found"));

    paymentInfo.setPaymentStatus("COMPLETED");
    paymentInfo.setPaidAt(LocalDateTime.now());
    paymentInfo.setNotes(notes != null ? notes : "Manually marked as paid by admin");
    studentPaymentInfoRepo.save(paymentInfo);

    log.info("Manual payment recorded for student {} from org {}", studentId, organizationId);
  }

  @Transactional
  public void processRefund(String razorpayPaymentId, Long refundAmount, String reason) {
    RazorpayOrder order = razorpayOrderRepo.findByRazorpayPaymentId(razorpayPaymentId)
      .orElseThrow(() -> new IllegalArgumentException("Payment not found"));

    PaymentGateway activeGateway = resolveActiveGateway(order.getOrganizationId());
    if (activeGateway != PaymentGateway.RAZORPAY) {
      processRefundViaGateway(activeGateway, order, razorpayPaymentId, refundAmount, reason);
      return;
    }

    OrgRazorpayConfig config = orgConfigRepo.findByOrganizationId(order.getOrganizationId())
      .orElseThrow(() -> new IllegalStateException("Config not found"));

    // Call Razorpay refund API
    String refundId = razorpayService.refundPayment(
      config.getRazorpayKeyId(),
      config.getRazorpayKeySecret(),
      razorpayPaymentId,
      refundAmount
    );

    // Record refund
    PaymentRefund refund = PaymentRefund.builder()
      .studentId(order.getStudentId())
      .razorpayRefundId(refundId)
      .razorpayPaymentId(razorpayPaymentId)
      .amount(refundAmount)
      .reason(reason)
      .status("PENDING")
      .build();
    refund.setOrganizationId(order.getOrganizationId());
    refundRepo.save(refund);

    log.info("Refund initiated: {} for payment {}", refundId, razorpayPaymentId);
  }

  /** Non-Razorpay counterpart to the block above, dispatched via {@link PaymentGatewayResolver}. */
  private void processRefundViaGateway(PaymentGateway gateway, RazorpayOrder order,
                                        String paymentReference, Long refundAmount, String reason) {
    String refundId = gatewayResolver.resolve(gateway).refund(order.getOrganizationId(), paymentReference, refundAmount);

    PaymentRefund refund = PaymentRefund.builder()
      .studentId(order.getStudentId())
      .razorpayRefundId(refundId)
      .razorpayPaymentId(paymentReference)
      .amount(refundAmount)
      .reason(reason)
      .status("PENDING")
      .build();
    refund.setOrganizationId(order.getOrganizationId());
    refundRepo.save(refund);

    log.info("Refund initiated: {} for payment {} via {}", refundId, paymentReference, gateway);
  }

  /**
   * Non-Razorpay counterpart to {@link #handlePaymentSuccess(String, String, String)}, used by
   * the PayU/Cashfree webhook endpoints. Takes the gateway's own raw callback field names (not
   * just orderId/paymentId/signature) because PayU's reverse-hash check needs status/email/
   * firstname/productinfo/amount too; Cashfree only reads orderId back out of this map.
   */
  @Transactional
  public void handleGatewayPaymentSuccess(PaymentGateway gateway, String orderId, Map<String, String> callbackParams) {
    RazorpayOrder order = razorpayOrderRepo.findByRazorpayOrderId(orderId)
      .orElseThrow(() -> new IllegalArgumentException("Order not found: " + orderId));

    String paymentId = gatewayResolver.resolve(gateway).verifyAndCapture(order.getOrganizationId(), callbackParams);

    order.setRazorpayPaymentId(paymentId);
    order.setRazorpaySignature(callbackParams.get("signature"));
    order.setStatus("CAPTURED");
    razorpayOrderRepo.save(order);

    StudentPaymentInfo paymentInfo = studentPaymentInfoRepo
      .findByStudentIdAndOrganizationId(order.getStudentId(), order.getOrganizationId())
      .orElseThrow(() -> new IllegalArgumentException("Payment info not found"));

    paymentInfo.setPaymentStatus("COMPLETED");
    paymentInfo.setPaidAt(LocalDateTime.now());
    studentPaymentInfoRepo.save(paymentInfo);

    log.info("Payment completed for student {} from org {} via {}", order.getStudentId(), order.getOrganizationId(), gateway);
  }

  /**
   * Verify and record a payment that came back through Razorpay Standard Checkout's
   * browser redirect ({@code callback_url}). Same capture flow as the webhook, but the
   * HMAC is keyed with the org's Key Secret rather than the webhook secret.
   */
  @Transactional
  public void handleRazorpayCheckoutRedirect(String razorpayOrderId, String razorpayPaymentId, String signature) {
    RazorpayOrder order = razorpayOrderRepo.findByRazorpayOrderId(razorpayOrderId)
      .orElseThrow(() -> new IllegalArgumentException("Order not found: " + razorpayOrderId));

    OrgRazorpayConfig config = orgConfigRepo.findByOrganizationId(order.getOrganizationId())
      .orElseThrow(() -> new IllegalStateException("Razorpay config not found"));

    if (!razorpayService.verifyCheckoutSignature(razorpayOrderId, razorpayPaymentId, signature, config.getRazorpayKeySecret())) {
      log.warn("Checkout signature verification failed for payment {}", razorpayPaymentId);
      throw new SecurityException("Invalid signature");
    }

    order.setRazorpayPaymentId(razorpayPaymentId);
    order.setRazorpaySignature(signature);
    order.setStatus("CAPTURED");
    razorpayOrderRepo.save(order);

    StudentPaymentInfo paymentInfo = studentPaymentInfoRepo
      .findByStudentIdAndOrganizationId(order.getStudentId(), order.getOrganizationId())
      .orElseThrow(() -> new IllegalArgumentException("Payment info not found"));

    paymentInfo.setPaymentStatus("COMPLETED");
    paymentInfo.setPaidAt(LocalDateTime.now());
    studentPaymentInfoRepo.save(paymentInfo);

    log.info("Payment completed for student {} from org {} via Razorpay checkout redirect",
        order.getStudentId(), order.getOrganizationId());
  }

  /**
   * Poll a gateway order's live status and capture it if paid. Used by the mobile app
   * after Cashfree's hosted checkout closes: the app has no server push, so it asks
   * this endpoint until the order flips to PAID (or gives up).
   * Returns {paid: bool, error?: string}.
   */
  @Transactional
  public Map<String, Object> checkGatewayOrderStatus(String orderId) {
    RazorpayOrder order = razorpayOrderRepo.findByRazorpayOrderId(orderId)
      .orElseThrow(() -> new IllegalArgumentException("Order not found: " + orderId));

    if ("CAPTURED".equals(order.getStatus())) {
      return Map.of("paid", true);
    }

    PaymentGateway activeGateway = resolveActiveGateway(order.getOrganizationId());
    try {
      handleGatewayPaymentSuccess(activeGateway, orderId, Map.of("orderId", orderId));
      return Map.of("paid", true);
    } catch (Exception e) {
      // Not paid yet (or verification failed) — normal while the student is still
      // on the gateway's page, so surface it as a plain status rather than an error.
      log.debug("Order {} not captured yet: {}", orderId, e.getMessage());
      return Map.of("paid", false, "error", e.getMessage() != null ? e.getMessage() : "not paid");
    }
  }

  // ------------------------------------------------------------------ admin views

  /**
   * Every student's fee row for the current tenant, cash and online alike, enriched
   * with the student's name and the most recent gateway attempt.
   *
   * <p>Driven off {@code student_payment_info} rather than {@code razorpay_orders} so
   * that cash students — who never produce an order — still appear on the payments
   * page instead of silently vanishing from the ledger.
   */
  public List<Map<String, Object>> listTransactions() {
    List<Map<String, Object>> rows = new ArrayList<>();
    for (StudentPaymentInfo info : studentPaymentInfoRepo.findAll()) {
      Map<String, Object> row = new LinkedHashMap<>();
      row.put("studentId", info.getStudentId());
      userRepository.findById(info.getStudentId()).ifPresent(u -> {
        row.put("studentName", u.getName());
        row.put("studentEmail", u.getEmail());
      });
      row.putIfAbsent("studentName", "Student #" + info.getStudentId());
      row.putIfAbsent("studentEmail", null);
      row.put("paymentMethod", info.getPaymentMethod());
      row.put("paymentStatus", info.getPaymentStatus());
      row.put("amountDue", info.getAmountDue() != null ? info.getAmountDue() : 0L);
      row.put("paidAt", info.getPaidAt());
      row.put("notes", info.getNotes());

      List<RazorpayOrder> orders = razorpayOrderRepo.findByStudentIdOrderByIdDesc(info.getStudentId());
      if (!orders.isEmpty()) {
        RazorpayOrder latest = orders.get(0);
        row.put("razorpayOrderId", latest.getRazorpayOrderId());
        row.put("razorpayPaymentId", latest.getRazorpayPaymentId());
        row.put("attemptCount", latest.getAttemptCount());
        row.put("lastError", latest.getLastError());
      }
      rows.add(row);
    }
    return rows;
  }

  /**
   * A single student's payment history, most recent first.
   *
   * <p>Unions two sources: every {@code RazorpayOrder} attempt (ONLINE) plus a
   * synthesized entry from {@code StudentPaymentInfo} when the student is on CASH —
   * cash payments never produce a Razorpay order, so skipping that row would make
   * a fully-paid cash student's history look empty.
   */
  public List<com.institute.lms.dto.payment.PaymentHistoryEntryDTO> getPaymentHistory(Long studentId, Long organizationId) {
    List<com.institute.lms.dto.payment.PaymentHistoryEntryDTO> entries = new ArrayList<>();

    for (RazorpayOrder order : razorpayOrderRepo.findByStudentIdOrderByIdDesc(studentId)) {
      entries.add(new com.institute.lms.dto.payment.PaymentHistoryEntryDTO(
        "ONLINE",
        order.getStatus(),
        order.getAmount(),
        order.getCurrency(),
        order.getCreatedAt(),
        order.getRazorpayOrderId(),
        order.getRazorpayPaymentId(),
        order.getLastError()
      ));
    }

    studentPaymentInfoRepo.findByStudentIdAndOrganizationId(studentId, organizationId)
      .filter(info -> "CASH".equals(info.getPaymentMethod()) && info.isPaid())
      .ifPresent(info -> entries.add(new com.institute.lms.dto.payment.PaymentHistoryEntryDTO(
        "CASH",
        info.getPaymentStatus(),
        info.getAmountDue(),
        "INR",
        info.getPaidAt(),
        null,
        null,
        info.getNotes()
      )));

    entries.sort((a, b) -> {
      if (a.getDate() == null) return 1;
      if (b.getDate() == null) return -1;
      return b.getDate().compareTo(a.getDate());
    });
    return entries;
  }

  /** Headline figures for the payments page. All amounts in paise. */
  public Map<String, Object> summary() {
    long collected = 0, pending = 0;
    int cashCount = 0, onlineCount = 0, paidCount = 0, pendingCount = 0;

    for (StudentPaymentInfo info : studentPaymentInfoRepo.findAll()) {
      long amount = info.getAmountDue() != null ? info.getAmountDue() : 0L;
      if ("ONLINE".equals(info.getPaymentMethod())) onlineCount++; else cashCount++;
      if (info.isPaid()) {
        collected += amount;
        paidCount++;
      } else {
        pending += amount;
        pendingCount++;
      }
    }

    long refunded = refundRepo.findAll().stream()
            .filter(r -> !"FAILED".equals(r.getStatus()))
            .mapToLong(r -> r.getAmount() != null ? r.getAmount() : 0L)
            .sum();

    Map<String, Object> out = new LinkedHashMap<>();
    out.put("totalCollected", collected);
    out.put("pendingAmount", pending);
    out.put("refundedAmount", refunded);
    out.put("cashCount", cashCount);
    out.put("onlineCount", onlineCount);
    out.put("paidCount", paidCount);
    out.put("pendingCount", pendingCount);
    return out;
  }

  // ------------------------------------------------------------- gateway settings

  public Optional<OrgRazorpayConfig> getConfig(Long organizationId) {
    return orgConfigRepo.findByOrganizationId(organizationId);
  }

  /**
   * Upsert the tenant's gateway credentials. A blank secret means "leave the stored
   * one alone" — the admin page never sends secrets back down, so echoing a masked
   * value into the form must not overwrite the real key.
   */
  @Transactional
  public OrgRazorpayConfig saveConfig(Long organizationId, String keyId, String keySecret,
                                      String webhookSecret, Long amountPerStudent, Boolean enabled) {
    OrgRazorpayConfig config = orgConfigRepo.findByOrganizationId(organizationId)
            .orElseGet(() -> {
              OrgRazorpayConfig fresh = new OrgRazorpayConfig();
              fresh.setOrganizationId(organizationId);
              return fresh;
            });

    if (keyId != null && !keyId.isBlank()) config.setRazorpayKeyId(keyId.trim());
    if (keySecret != null && !keySecret.isBlank()) config.setRazorpayKeySecret(keySecret.trim());
    if (webhookSecret != null && !webhookSecret.isBlank()) config.setRazorpayWebhookSecret(webhookSecret.trim());
    if (amountPerStudent != null) config.setAmountPerStudent(amountPerStudent);
    if (enabled != null) config.setPaymentEnabled(enabled);

    // Turning collection on without credentials would strand every new ONLINE student
    // at a payment screen that can never create an order, so refuse it up front.
    if (Boolean.TRUE.equals(config.getPaymentEnabled())
            && (config.getRazorpayKeyId() == null || config.getRazorpayKeyId().isBlank()
             || config.getRazorpayKeySecret() == null || config.getRazorpayKeySecret().isBlank())) {
      throw new IllegalArgumentException("Add your Razorpay Key ID and Key Secret before enabling online payments.");
    }

    return orgConfigRepo.save(config);
  }
}
