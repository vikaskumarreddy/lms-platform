package com.institute.lms.service.payment;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.institute.lms.entity.OrgPaymentGatewayConfig;
import com.institute.lms.entity.PaymentGateway;
import com.institute.lms.repository.OrgPaymentGatewayConfigRepository;
import com.institute.lms.service.OrgPaymentGatewayConfigService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Cashfree Payment Gateway adapter (Orders API, v2023-08-01). Unlike PayU's
 * browser-redirect flow, Cashfree is a plain REST order-create that returns a
 * {@code payment_session_id} for the client SDK to resume, plus a get-order
 * status check used here for verification rather than reproducing Cashfree's
 * webhook HMAC signature scheme.
 *
 * <p>Credentials expected in {@code credentialsJson}: {@code appId},
 * {@code secretKey}, and optionally {@code mode} ("TEST" or "LIVE", defaults to TEST).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class CashfreeGatewayAdapter implements PaymentGatewayService {
    private static final String CASHFREE_TEST_BASE = "https://sandbox.cashfree.com/pg";
    private static final String CASHFREE_LIVE_BASE = "https://api.cashfree.com/pg";
    private static final String API_VERSION = "2023-08-01";

    private final OrgPaymentGatewayConfigRepository configRepository;
    private final OrgPaymentGatewayConfigService configService;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Override
    public PaymentGateway getGateway() {
        return PaymentGateway.CASHFREE;
    }

    @Override
    public Map<String, Object> createOrder(Long organizationId, Long amount, String currency,
                                            String receiptRef, Map<String, String> customer) {
        Map<String, String> creds = credentialsFor(organizationId);
        String appId = require(creds, "appId");
        String secretKey = require(creds, "secretKey");
        String baseUrl = baseUrlFor(creds);

        String orderId = receiptRef != null ? receiptRef : "order_" + System.currentTimeMillis();
        String customerId = customer != null ? customer.getOrDefault("customerId", "cust_" + organizationId) : "cust_" + organizationId;
        String phone = customer != null ? customer.getOrDefault("phone", "9999999999") : "9999999999";
        String email = customer != null ? customer.getOrDefault("email", "") : "";
        String name = customer != null ? customer.getOrDefault("name", "Student") : "Student";

        Map<String, Object> customerDetails = new LinkedHashMap<>();
        customerDetails.put("customer_id", customerId);
        customerDetails.put("customer_phone", phone);
        if (!email.isBlank()) customerDetails.put("customer_email", email);
        customerDetails.put("customer_name", name);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("order_id", orderId);
        body.put("order_amount", amount / 100.0); // Cashfree wants rupees, not paise
        body.put("order_currency", currency != null ? currency : "INR");
        body.put("customer_details", customerDetails);

        HttpHeaders headers = cashfreeHeaders(appId, secretKey);
        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(
                    baseUrl + "/orders", new HttpEntity<>(body, headers), Map.class);
            Map<?, ?> responseBody = response.getBody();
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("orderId", orderId);
            result.put("cfOrderId", responseBody != null ? responseBody.get("cf_order_id") : null);
            result.put("paymentSessionId", responseBody != null ? responseBody.get("payment_session_id") : null);
            result.put("amount", amount);
            result.put("currency", currency != null ? currency : "INR");
            result.put("mode", creds.getOrDefault("mode", "TEST"));
            return result;
        } catch (Exception e) {
            log.error("Cashfree order creation failed for org {}", organizationId, e);
            throw new IllegalStateException("Cashfree order creation failed: " + e.getMessage());
        }
    }

    @Override
    public String verifyAndCapture(Long organizationId, Map<String, String> callbackParams) {
        Map<String, String> creds = credentialsFor(organizationId);
        String appId = require(creds, "appId");
        String secretKey = require(creds, "secretKey");
        String baseUrl = baseUrlFor(creds);

        String orderId = callbackParams.get("orderId");
        HttpHeaders headers = cashfreeHeaders(appId, secretKey);
        try {
            ResponseEntity<String> response = restTemplate.exchange(
                    baseUrl + "/orders/" + orderId, org.springframework.http.HttpMethod.GET,
                    new HttpEntity<>(headers), String.class);
            JsonNode order = objectMapper.readTree(response.getBody());
            String orderStatus = order.path("order_status").asText("");
            if (!"PAID".equalsIgnoreCase(orderStatus)) {
                throw new IllegalStateException("Cashfree order not paid: " + orderStatus);
            }
            JsonNode payments = order.path("payments");
            return payments.isArray() && payments.size() > 0
                    ? payments.get(0).path("cf_payment_id").asText(orderId)
                    : orderId;
        } catch (IllegalStateException e) {
            throw e;
        } catch (Exception e) {
            log.error("Cashfree order verification failed for order {}", orderId, e);
            throw new IllegalStateException("Cashfree verification failed: " + e.getMessage());
        }
    }

    @Override
    public String refund(Long organizationId, String paymentReference, Long amount) {
        Map<String, String> creds = credentialsFor(organizationId);
        String appId = require(creds, "appId");
        String secretKey = require(creds, "secretKey");
        String baseUrl = baseUrlFor(creds);

        String refundId = "refund_" + System.currentTimeMillis();
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("refund_amount", amount / 100.0);
        body.put("refund_id", refundId);

        HttpHeaders headers = cashfreeHeaders(appId, secretKey);
        try {
            restTemplate.postForEntity(
                    baseUrl + "/orders/" + paymentReference + "/refunds", new HttpEntity<>(body, headers), Map.class);
            return refundId;
        } catch (Exception e) {
            log.error("Cashfree refund failed for order {}", paymentReference, e);
            throw new IllegalStateException("Cashfree refund failed: " + e.getMessage());
        }
    }

    private HttpHeaders cashfreeHeaders(String appId, String secretKey) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("x-client-id", appId);
        headers.set("x-client-secret", secretKey);
        headers.set("x-api-version", API_VERSION);
        return headers;
    }

    private String baseUrlFor(Map<String, String> creds) {
        boolean live = "LIVE".equalsIgnoreCase(creds.getOrDefault("mode", "TEST"));
        return live ? CASHFREE_LIVE_BASE : CASHFREE_TEST_BASE;
    }

    private Map<String, String> credentialsFor(Long organizationId) {
        Optional<OrgPaymentGatewayConfig> config = configRepository.findByOrganizationIdAndGateway(organizationId, PaymentGateway.CASHFREE);
        if (config.isEmpty() || !Boolean.TRUE.equals(config.get().getPaymentEnabled())) {
            throw new IllegalStateException("Cashfree is not configured for this organization");
        }
        return configService.parseCredentials(config.get());
    }

    private static String require(Map<String, String> creds, String key) {
        String value = creds.get(key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Missing Cashfree credential: " + key);
        }
        return value;
    }
}
