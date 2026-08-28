package com.institute.lms.service.payment;

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
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * PayU (India) hosted-checkout adapter. PayU's flow is a browser redirect
 * rather than a plain REST order-create: the merchant computes a SHA-512 hash
 * over its key/txnid/amount/salt and posts a form to PayU's payment page, and
 * PayU redirects back with its own reverse-hash to verify. This adapter
 * returns the fields the caller needs to build that redirect form, and
 * verifies the callback's reverse hash.
 *
 * <p>Credentials expected in {@code credentialsJson}: {@code key}, {@code salt},
 * and optionally {@code mode} ("TEST" or "LIVE", defaults to TEST).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class PayUGatewayAdapter implements PaymentGatewayService {
    private static final String PAYU_TEST_URL = "https://test.payu.in/_payment";
    private static final String PAYU_LIVE_URL = "https://secure.payu.in/_payment";

    private final OrgPaymentGatewayConfigRepository configRepository;
    private final OrgPaymentGatewayConfigService configService;
    private final RestTemplate restTemplate;

    @Override
    public PaymentGateway getGateway() {
        return PaymentGateway.PAYU;
    }

    @Override
    public Map<String, Object> createOrder(Long organizationId, Long amount, String currency,
                                            String receiptRef, Map<String, String> customer) {
        Map<String, String> creds = credentialsFor(organizationId);
        String key = require(creds, "key");
        String salt = require(creds, "salt");
        boolean live = "LIVE".equalsIgnoreCase(creds.getOrDefault("mode", "TEST"));

        String txnId = receiptRef != null ? receiptRef : "txn_" + System.currentTimeMillis();
        String amountStr = String.format("%.2f", amount / 100.0); // PayU wants rupees, not paise
        String productInfo = "Student enrollment";
        String firstName = customer != null ? customer.getOrDefault("name", "Student") : "Student";
        String email = customer != null ? customer.getOrDefault("email", "") : "";
        String phone = customer != null ? customer.getOrDefault("phone", "") : "";

        // PayU forward hash: sha512(key|txnid|amount|productinfo|firstname|email|udf1..5||||||salt)
        String hashSequence = String.join("|", key, txnId, amountStr, productInfo, firstName, email,
                "", "", "", "", "", "", "", "", "", "", salt);
        String hash = sha512(hashSequence);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("orderId", txnId);
        result.put("actionUrl", live ? PAYU_LIVE_URL : PAYU_TEST_URL);
        result.put("key", key);
        result.put("txnid", txnId);
        result.put("amount", amountStr);
        result.put("productinfo", productInfo);
        result.put("firstname", firstName);
        result.put("email", email);
        result.put("phone", phone);
        result.put("hash", hash);
        return result;
    }

    @Override
    public String verifyAndCapture(Long organizationId, Map<String, String> callbackParams) {
        Map<String, String> creds = credentialsFor(organizationId);
        String salt = require(creds, "salt");
        String key = require(creds, "key");

        String status = callbackParams.getOrDefault("status", "");
        String txnId = callbackParams.get("orderId");
        String mihpayid = callbackParams.get("paymentId");
        String receivedHash = callbackParams.get("signature");

        // PayU reverse hash: sha512(salt|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)
        String email = callbackParams.getOrDefault("email", "");
        String firstName = callbackParams.getOrDefault("firstname", "");
        String productInfo = callbackParams.getOrDefault("productinfo", "");
        String amount = callbackParams.getOrDefault("amount", "");
        String hashSequence = String.join("|", salt, status, "", "", "", "", "", "", "", "", "",
                email, firstName, productInfo, amount, txnId, key);
        String expectedHash = sha512(hashSequence);

        if (receivedHash == null || !expectedHash.equalsIgnoreCase(receivedHash)) {
            throw new SecurityException("Invalid PayU hash");
        }
        if (!"success".equalsIgnoreCase(status)) {
            throw new IllegalStateException("PayU payment not successful: " + status);
        }
        return mihpayid;
    }

    @Override
    public String refund(Long organizationId, String paymentReference, Long amount) {
        Map<String, String> creds = credentialsFor(organizationId);
        String key = require(creds, "key");
        String salt = require(creds, "salt");

        // PayU refund API: postservice?form=2, command=cancel_refund_transaction
        String var1 = paymentReference;
        String hashSequence = String.join("|", key, "cancel_refund_transaction", var1, salt);
        String hash = sha512(hashSequence);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        LinkedMultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("key", key);
        form.add("command", "cancel_refund_transaction");
        form.add("var1", var1);
        form.add("var2", String.format("%.2f", amount / 100.0));
        form.add("hash", hash);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(
                    "https://info.payu.in/merchant/postservice?form=2", new HttpEntity<>(form, headers), Map.class);
            Object refundId = response.getBody() != null ? response.getBody().get("request_id") : null;
            return refundId != null ? String.valueOf(refundId) : "PAYU_REFUND_" + System.currentTimeMillis();
        } catch (Exception e) {
            log.error("PayU refund failed for payment {}", paymentReference, e);
            throw new IllegalStateException("PayU refund failed: " + e.getMessage());
        }
    }

    private Map<String, String> credentialsFor(Long organizationId) {
        Optional<OrgPaymentGatewayConfig> config = configRepository.findByOrganizationIdAndGateway(organizationId, PaymentGateway.PAYU);
        if (config.isEmpty() || !Boolean.TRUE.equals(config.get().getPaymentEnabled())) {
            throw new IllegalStateException("PayU is not configured for this organization");
        }
        return configService.parseCredentials(config.get());
    }

    private static String require(Map<String, String> creds, String key) {
        String value = creds.get(key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Missing PayU credential: " + key);
        }
        return value;
    }

    private static String sha512(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-512");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Could not compute PayU hash", e);
        }
    }
}
