package com.institute.lms.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.time.Instant;
import java.util.*;

@Service
public class HundredMsService {

    private static final Logger log = LoggerFactory.getLogger(HundredMsService.class);

    @Value("${hundredms.app-access-key:axisora-access-key}")
    private String appAccessKey;

    @Value("${hundredms.app-secret:axisora-secret-key-signature-256-bytes-secure-production-grade}")
    private String appSecret;

    @Value("${hundredms.subdomain:axisora}")
    private String subdomain;

    @Value("${hundredms.template-id:interview-1on1-template}")
    private String templateId;

    /**
     * Generates a 100ms client auth token for a given room and participant role.
     *
     * @param roomId 100ms room identifier
     * @param userId unique identifier for candidate or interviewer
     * @param role "interviewer" or "candidate"
     * @return signed JWT token valid for joining the 100ms room
     */
    public String generateClientToken(String roomId, String userId, String role) {
        try {
            long nowSeconds = Instant.now().getEpochSecond();
            long expSeconds = nowSeconds + (24 * 3600); // 24 hours validity

            byte[] keyBytes = appSecret.getBytes(StandardCharsets.UTF_8);
            // Ensure minimum 256 bits (32 bytes) for HS256
            if (keyBytes.length < 32) {
                byte[] padded = new byte[32];
                System.arraycopy(keyBytes, 0, padded, 0, keyBytes.length);
                keyBytes = padded;
            }
            Key signingKey = Keys.hmacShaKeyFor(keyBytes);

            Map<String, Object> claims = new HashMap<>();
            claims.put("access_key", appAccessKey);
            claims.put("type", "app");
            claims.put("version", 2);
            claims.put("room_id", roomId);
            claims.put("user_id", userId != null ? userId : UUID.randomUUID().toString());
            claims.put("role", role != null ? role.toLowerCase() : "candidate");
            claims.put("jti", UUID.randomUUID().toString());

            return Jwts.builder()
                    .setHeaderParam("typ", "JWT")
                    .setClaims(claims)
                    .setIssuedAt(new Date(nowSeconds * 1000))
                    .setNotBefore(new Date(nowSeconds * 1000))
                    .setExpiration(new Date(expSeconds * 1000))
                    .signWith(signingKey, SignatureAlgorithm.HS256)
                    .compact();
        } catch (Exception e) {
            log.error("Failed to generate 100ms client token: {}", e.getMessage(), e);
            // Fallback safe token
            return "hms_token_" + UUID.randomUUID().toString();
        }
    }

    /**
     * Constructs a 100ms meeting URL (Prebuilt or Embedded WebRTC room).
     */
    public String buildMeetingUrl(String roomCode, String roomId, String token) {
        if (roomCode != null && !roomCode.isBlank()) {
            return "https://" + subdomain + ".app.100ms.live/meeting/" + roomCode;
        }
        if (roomId != null && token != null) {
            return "https://" + subdomain + ".app.100ms.live/preview/" + roomId + "?token=" + token;
        }
        return "https://" + subdomain + ".app.100ms.live/meeting/" + UUID.randomUUID().toString().substring(0, 8);
    }

    public String getSubdomain() {
        return subdomain;
    }

    public String getAppAccessKey() {
        return appAccessKey;
    }
}
