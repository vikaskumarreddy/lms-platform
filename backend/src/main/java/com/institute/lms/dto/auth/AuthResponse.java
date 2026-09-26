package com.institute.lms.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private String tokenType;
    private long expiresIn;
    private UserInfo user;
    private java.util.Map<String, Object> paymentOrder;
    private String gateway;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
        public static class UserInfo {
        private Long id;
        private String email;
        private String fullName;
        private String role;
        private List<String> roles;
        private Long planId;
        private Long batchId;
        private Long organizationId;
        // Payment info for students
        private Boolean paymentRequired;
        private String paymentMethod;
        private String paymentStatus;
        private Long amountDue;
    }
}
