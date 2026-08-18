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
    }
}
