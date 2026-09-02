package com.institute.lms.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

@Service
@RequiredArgsConstructor
@Slf4j
public class RazorpayService {
  private static final String RAZORPAY_API = "https://api.razorpay.com/v1";
  private final RestTemplate restTemplate;
  private final ObjectMapper objectMapper;

  /**
   * Create an order using org's Razorpay account.
   * Each org has unique key_id and key_secret.
   */
  public Map<String, Object> createOrder(String keyId, String keySecret, Long amount, String currency, String description) {
    try {
      String url = RAZORPAY_API + "/orders";

      // Build request
      Map<String, Object> payload = new LinkedHashMap<>();
      payload.put("amount", amount); // in paise
      payload.put("currency", currency);
      payload.put("receipt", "receipt_" + System.currentTimeMillis());
      payload.put("description", description);

      String jsonPayload = objectMapper.writeValueAsString(payload);

      // Basic auth: keyId:keySecret
      String auth = Base64.getEncoder()
        .encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

      HttpHeaders headers = new HttpHeaders();
      headers.setContentType(MediaType.APPLICATION_JSON);
      headers.set("Authorization", "Basic " + auth);

      var request = new org.springframework.http.HttpEntity<>(jsonPayload, headers);
      var response = restTemplate.postForEntity(url, request, String.class);

      if (response.getStatusCode() == HttpStatus.CREATED) {
        return objectMapper.readValue(response.getBody(), Map.class);
      } else {
        throw new RuntimeException("Failed to create order: " + response.getStatusCode());
      }
    } catch (Exception e) {
      log.error("Error creating Razorpay order", e);
      throw new RuntimeException("Order creation failed: " + e.getMessage(), e);
    }
  }

  /**
   * Verify webhook signature using org's webhook secret.
   * webhook_body + webhook_secret -> HMAC-SHA256 should match signature
   */
  public boolean verifySignature(String orderId, String paymentId, String signature, String webhookSecret) {
    try {
      String payload = orderId + "|" + paymentId;
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      String computed = String.format("%064x", new java.math.BigInteger(1, mac.doFinal(payload.getBytes(StandardCharsets.UTF_8))));
      return MessageDigest.isEqual(computed.getBytes(), signature.getBytes());
    } catch (Exception e) {
      log.error("Signature verification error", e);
      return false;
    }
  }

  /**
   * Verify the signature Razorpay attaches when Standard Checkout redirects back to
   * {@code callback_url}. Unlike the webhook payload this HMAC is keyed with the
   * account's Key Secret, not the webhook secret, so it needs its own entry point.
   */
  public boolean verifyCheckoutSignature(String orderId, String paymentId, String signature, String keySecret) {
    return verifySignature(orderId, paymentId, signature, keySecret);
  }

  /**
   * Refund a payment using org's credentials.
   */
  public String refundPayment(String keyId, String keySecret, String paymentId, Long amount) {
    try {
      String url = RAZORPAY_API + "/payments/" + paymentId + "/refund";

      Map<String, Object> payload = new LinkedHashMap<>();
      payload.put("amount", amount);

      String jsonPayload = objectMapper.writeValueAsString(payload);

      String auth = Base64.getEncoder()
        .encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

      HttpHeaders headers = new HttpHeaders();
      headers.setContentType(MediaType.APPLICATION_JSON);
      headers.set("Authorization", "Basic " + auth);

      var request = new org.springframework.http.HttpEntity<>(jsonPayload, headers);
      var response = restTemplate.postForEntity(url, request, String.class);

      Map<String, Object> result = objectMapper.readValue(response.getBody(), Map.class);
      return (String) result.get("id");
    } catch (Exception e) {
      log.error("Error refunding payment {}", paymentId, e);
      throw new RuntimeException("Refund failed: " + e.getMessage(), e);
    }
  }

  /**
   * Fetch payment details from Razorpay API.
   */
  public Map<String, Object> getPaymentDetails(String keyId, String keySecret, String paymentId) {
    try {
      String url = RAZORPAY_API + "/payments/" + paymentId;

      String auth = Base64.getEncoder()
        .encodeToString((keyId + ":" + keySecret).getBytes(StandardCharsets.UTF_8));

      HttpHeaders headers = new HttpHeaders();
      headers.set("Authorization", "Basic " + auth);

      var request = new org.springframework.http.HttpEntity<>("", headers);
      var response = restTemplate.getForEntity(url, String.class);

      return objectMapper.readValue(response.getBody(), Map.class);
    } catch (Exception e) {
      log.error("Error fetching payment details", e);
      throw new RuntimeException("Failed to fetch payment details: " + e.getMessage(), e);
    }
  }
}
